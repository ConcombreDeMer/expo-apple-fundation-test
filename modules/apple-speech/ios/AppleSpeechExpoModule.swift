import AVFoundation
import ExpoModulesCore
import Foundation
import Speech

struct AppleSpeechStartOptionsRecord: Record {
  @Field var locale: String?
  @Field var reportPartialResults: Bool = true
}

final class AppleSpeechRecognitionPayload: NSObject {
  let transcript: String
  let isFinalResult: Bool
  let errorCode: String?
  let errorMessage: String?

  init(
    transcript: String,
    isFinalResult: Bool,
    errorCode: String?,
    errorMessage: String?
  ) {
    self.transcript = transcript
    self.isFinalResult = isFinalResult
    self.errorCode = errorCode
    self.errorMessage = errorMessage
  }
}

public final class AppleSpeechExpoModule: Module, @unchecked Sendable {
  private let audioEngine = AVAudioEngine()
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var speechRecognizer: SFSpeechRecognizer?
  private var currentLocale: String?
  private var currentState: String = "idle"
  private var interruptionObserver: NSObjectProtocol?

  public func definition() -> ModuleDefinition {
    Name("AppleSpeechExpoModule")

    Events("onPartialResult", "onFinalResult", "onError", "onStateChange")

    OnCreate {
      DispatchQueue.main.async {
        self.installInterruptionObserver()
      }
    }

    OnDestroy {
      DispatchQueue.main.async {
        self.teardownRecognition(resetLocale: true)
        self.removeInterruptionObserver()
      }
    }

    AsyncFunction("requestPermissions") { () async -> [String: Bool] in
      let microphone = await Self.requestMicrophonePermission()
      let speech = await Self.requestSpeechPermission()
      return [
        "microphone": microphone,
        "speech": speech
      ]
    }

    AsyncFunction("startTranscription") { (options: AppleSpeechStartOptionsRecord?) async throws in
      let resolvedOptions = options ?? AppleSpeechStartOptionsRecord()
      let locale = (resolvedOptions.locale ?? "fr-FR").trimmingCharacters(in: .whitespacesAndNewlines)
      let localeIdentifier = locale.isEmpty ? "fr-FR" : locale

      let permissions = [
        "microphone": await Self.requestMicrophonePermission(),
        "speech": await Self.requestSpeechPermission()
      ]

      guard permissions["microphone"] == true else {
        throw Self.exception(
          code: "ERR_MICROPHONE_PERMISSION_DENIED",
          description: "L'acces au microphone a ete refuse."
        )
      }

      guard permissions["speech"] == true else {
        throw Self.exception(
          code: "ERR_SPEECH_PERMISSION_DENIED",
          description: "L'autorisation de reconnaissance vocale a ete refusee."
        )
      }

      try await self.performOnMain {
        guard self.currentState != "listening", self.recognitionTask == nil else {
          throw Self.exception(
            code: "ERR_SPEECH_ALREADY_RUNNING",
            description: "Une transcription est deja en cours."
          )
        }

        guard let recognizer = SFSpeechRecognizer(
          locale: Locale(identifier: localeIdentifier)
        ) else {
          throw Self.exception(
            code: "ERR_SPEECH_UNSUPPORTED_LOCALE",
            description: "La langue demandee n'est pas prise en charge."
          )
        }

        guard recognizer.isAvailable else {
          throw Self.exception(
            code: "ERR_SPEECH_RECOGNIZER_UNAVAILABLE",
            description: "La reconnaissance vocale Apple est indisponible pour le moment."
          )
        }

        self.speechRecognizer = recognizer
        self.currentLocale = localeIdentifier
        try self.startAudioSession(
          recognizer: recognizer,
          reportPartialResults: resolvedOptions.reportPartialResults
        )
      }
    }

    AsyncFunction("stopTranscription") { () async in
      await self.performOnMain {
        guard self.currentState == "listening" || self.recognitionTask != nil else {
          self.sendStateChange("idle")
          return
        }

        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.recognitionRequest?.endAudio()
        self.sendStateChange("idle")
      }
    }
  }

  private func startAudioSession(recognizer: SFSpeechRecognizer, reportPartialResults: Bool) throws {
    teardownRecognition(resetLocale: false)

    let audioSession = AVAudioSession.sharedInstance()

    do {
      try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      throw Self.exception(
        code: "ERR_AUDIO_SESSION",
        description: "Impossible de configurer l'audio pour la transcription."
      )
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = reportPartialResults
    if #available(iOS 16.0, *) {
      request.addsPunctuation = true
    }

    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      request.append(buffer)
    }

    audioEngine.prepare()

    do {
      try audioEngine.start()
    } catch {
      inputNode.removeTap(onBus: 0)
      recognitionRequest = nil
      throw Self.exception(
        code: "ERR_AUDIO_ENGINE_START",
        description: "Impossible de demarrer l'ecoute du microphone."
      )
    }

    recognitionRequest = request
    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      let transcript =
        result?.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let isFinalResult = result?.isFinal ?? false
      let mappedErrorCode = error.map { self?.mapErrorCode($0) ?? "ERR_SPEECH_UNKNOWN" }
      let mappedErrorMessage = error.map(Self.message(for:))
      let payload = AppleSpeechRecognitionPayload(
        transcript: transcript,
        isFinalResult: isFinalResult,
        errorCode: mappedErrorCode,
        errorMessage: mappedErrorMessage
      )

      DispatchQueue.main.async { [weak self] in
        guard let self else {
          return
        }

        self.handleRecognitionPayload(payload)
      }
    }

    sendStateChange("listening")
  }

  private func teardownRecognition(resetLocale: Bool) {
    if audioEngine.isRunning {
      audioEngine.stop()
    }

    if audioEngine.inputNode.numberOfInputs > 0 {
      audioEngine.inputNode.removeTap(onBus: 0)
    }

    recognitionRequest?.endAudio()
    recognitionRequest = nil

    recognitionTask?.cancel()
    recognitionTask = nil
    speechRecognizer = nil

    do {
      try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
    }

    if resetLocale {
      currentLocale = nil
    }
  }

  private func installInterruptionObserver() {
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt

      DispatchQueue.main.async {
        guard let self,
              let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
          return
        }

        if type == .began {
          self.emitError(
            code: "ERR_AUDIO_INTERRUPTED",
            message: "La transcription a ete interrompue par iOS."
          )
          self.teardownRecognition(resetLocale: false)
          self.sendStateChange("idle")
        }
      }
    }
  }

  private func performOnMain(_ operation: @Sendable @escaping () -> Void) async {
    await withCheckedContinuation { continuation in
      DispatchQueue.main.async {
        operation()
        continuation.resume()
      }
    }
  }

  private func performOnMain<T: Sendable>(
    _ operation: @Sendable @escaping () throws -> T
  ) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.main.async {
        do {
          continuation.resume(returning: try operation())
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func removeInterruptionObserver() {
    if let interruptionObserver {
      NotificationCenter.default.removeObserver(interruptionObserver)
      self.interruptionObserver = nil
    }
  }

  private func emitError(code: String, message: String) {
    sendEvent("onError", [
      "code": code,
      "message": message
    ])
  }

  private func sendStateChange(_ nextState: String) {
    currentState = nextState
    sendEvent("onStateChange", [
      "state": nextState,
      "locale": currentLocale
    ])
  }

  private func mapErrorCode(_ error: Error) -> String {
    let nsError = error as NSError

    if nsError.domain == "kAFAssistantErrorDomain" {
      return "ERR_SPEECH_RECOGNITION_FAILED"
    }

    if nsError.domain == NSOSStatusErrorDomain {
      return "ERR_AUDIO_SESSION"
    }

    return "ERR_SPEECH_UNKNOWN"
  }

  private func handleRecognitionCallback(
    transcript: String,
    isFinalResult: Bool,
    errorCode: String?,
    errorMessage: String?
  ) {
    if !transcript.isEmpty {
      let eventBody: [String: Any?] = [
        "text": transcript,
        "isFinal": isFinalResult,
        "locale": currentLocale
      ]

      if isFinalResult {
        sendEvent("onFinalResult", eventBody)
      } else {
        sendEvent("onPartialResult", eventBody)
      }
    }

    if let errorCode, let errorMessage {
      emitError(code: errorCode, message: errorMessage)
      teardownRecognition(resetLocale: false)
      sendStateChange("error")
      sendStateChange("idle")
      return
    }

    if isFinalResult {
      teardownRecognition(resetLocale: false)
      sendStateChange("idle")
    }
  }
  private func handleRecognitionPayload(_ payload: AppleSpeechRecognitionPayload) {
    handleRecognitionCallback(
      transcript: payload.transcript,
      isFinalResult: payload.isFinalResult,
      errorCode: payload.errorCode,
      errorMessage: payload.errorMessage
    )
  }

  private static func requestSpeechPermission() async -> Bool {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status == .authorized)
      }
    }
  }

  private static func requestMicrophonePermission() async -> Bool {
    await withCheckedContinuation { continuation in
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  private static func exception(code: String, description: String) -> Exception {
    Exception(name: code, description: description, code: code)
  }

  private static func message(for error: Error) -> String {
    let nsError = error as NSError

    if nsError.domain == "kAFAssistantErrorDomain" {
      return "La transcription n'a pas pu aboutir."
    }

    if nsError.domain == NSOSStatusErrorDomain {
      return "Une erreur audio iOS a interrompu la transcription."
    }

    return error.localizedDescription
  }
}
