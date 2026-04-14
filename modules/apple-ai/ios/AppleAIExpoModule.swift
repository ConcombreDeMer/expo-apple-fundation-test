import ExpoModulesCore
import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct AppleAIPlannedOperation {
  let action: String
  let taskIndex: Int?
  let title: String?
}

@available(iOS 26.0, *)
@Generable
struct AppleAIPlannedResponse {
  let assistantMessage: String
  let operations: [AppleAIPlannedOperation]
}
#endif

struct AppleAITaskRecord: Record {
  @Field var id: String = ""
  @Field var title: String = ""
  @Field var completed: Bool = false
  @Field var createdAt: Double = 0
}

public final class AppleAIExpoModule: Module {
  public func definition() -> ModuleDefinition {
    Name("AppleAIExpoModule")

    AsyncFunction("getAvailability") { () -> [String: Any?] in
      Self.currentAvailability()
    }

    AsyncFunction("isAvailable") { () -> Bool in
      (Self.currentAvailability()["isAvailable"] as? Bool) ?? false
    }

    AsyncFunction("generateText") { (prompt: String) async throws -> String in
      try await Self.generateText(prompt: prompt)
    }

    AsyncFunction("summarizeTasks") { (tasks: [AppleAITaskRecord]) async throws -> String in
      try await Self.generateText(
        prompt: Self.buildSummaryPrompt(from: tasks),
        instructions: Self.assistantInstructions
      )
    }

    AsyncFunction("suggestPriorities") { (tasks: [AppleAITaskRecord]) async throws -> String in
      try await Self.generateText(
        prompt: Self.buildPrioritiesPrompt(from: tasks),
        instructions: Self.assistantInstructions
      )
    }

    AsyncFunction("turnNotesIntoTasks") { (input: String) async throws -> [String] in
      try await Self.turnNotesIntoTasks(input: input)
    }

    AsyncFunction("rewriteTask") { (title: String) async throws -> String in
      try await Self.generateText(
        prompt: Self.buildRewritePrompt(for: title),
        instructions: Self.assistantInstructions
      )
    }

    AsyncFunction("planAction") { (input: String, tasks: [AppleAITaskRecord]) async throws -> [String: Any?] in
      try await Self.planAction(input: input, tasks: tasks)
    }
  }

  private static let assistantInstructions = """
  Tu es un assistant local intégré à une app iPhone de to-do list.
  Réponds toujours en français. Sois naturel et décontracté.
  Ne fais aucune mention d'un service cloud ou d'un backend.
  """

  private static func currentAvailability() -> [String: Any?] {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
      return [
        "isAvailable": false,
        "reason": "Foundation Models requiert iOS 26 ou plus."
      ]
    }

    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      return [
        "isAvailable": true,
        "reason": nil
      ]
    case .unavailable(let reason):
      return [
        "isAvailable": false,
        "reason": Self.message(for: reason)
      ]
    }
#else
    return [
      "isAvailable": false,
      "reason": "Le framework Foundation Models n'est pas disponible avec cette version de Xcode."
    ]
#endif
  }

  private static func asExpoException(_ error: Error) -> Exception {
    if let exception = error as? Exception {
      return exception
    }

    return Exception(
      name: "ERR_APPLE_AI",
      description: Self.message(for: error),
      code: "ERR_APPLE_AI"
    )
  }

  private static func generateText(prompt: String, instructions: String? = nil) async throws -> String {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: "Foundation Models requiert iOS 26 ou plus.",
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPrompt.isEmpty else {
      throw Exception(
        name: "ERR_APPLE_AI_INVALID_PROMPT",
        description: "Le prompt ne peut pas être vide.",
        code: "ERR_APPLE_AI_INVALID_PROMPT"
      )
    }

    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      break
    case .unavailable(let reason):
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: Self.message(for: reason),
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let session = LanguageModelSession(
      model: model,
      instructions: instructions ?? Self.assistantInstructions
    )
    let response = try await session.respond(
      to: trimmedPrompt,
      options: GenerationOptions(temperature: 0.75)
    )
    return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
#else
    throw Exception(
      name: "ERR_APPLE_AI_UNAVAILABLE",
      description: "Le framework Foundation Models n'est pas disponible avec cette version de Xcode.",
      code: "ERR_APPLE_AI_UNAVAILABLE"
    )
#endif
  }

  private static func turnNotesIntoTasks(input: String) async throws -> [String] {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: "Foundation Models requiert iOS 26 ou plus.",
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else {
      throw Exception(
        name: "ERR_APPLE_AI_INVALID_PROMPT",
        description: "Les notes à transformer ne peuvent pas être vides.",
        code: "ERR_APPLE_AI_INVALID_PROMPT"
      )
    }

    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      break
    case .unavailable(let reason):
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: Self.message(for: reason),
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let session = LanguageModelSession(
      model: model,
      instructions: """
      Tu transformes des notes courtes en tâches actionnables.
      Réponds en français.
      Transforme les notes en tâches claires, naturelles et vraiment utiles.
      Les formulations peuvent être un peu plus vivantes tant qu'elles restent actionnables.
      """
    )

    let response = try await session.respond(
      to: """
      Transforme ces notes en une liste de tâches actionnables.
      Garde les tâches utiles, évite les doublons et reformule proprement si besoin.

      Notes:
      \(trimmedInput)
      """,
      generating: [String].self,
      options: GenerationOptions(temperature: 0.6)
    )

    return response.content
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
#else
    throw Exception(
      name: "ERR_APPLE_AI_UNAVAILABLE",
      description: "Le framework Foundation Models n'est pas disponible avec cette version de Xcode.",
      code: "ERR_APPLE_AI_UNAVAILABLE"
    )
#endif
  }

  private static func planAction(input: String, tasks: [AppleAITaskRecord]) async throws -> [String: Any?] {
#if canImport(FoundationModels)
    guard #available(iOS 26.0, *) else {
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: "Foundation Models requiert iOS 26 ou plus.",
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInput.isEmpty else {
      throw Exception(
        name: "ERR_APPLE_AI_INVALID_PROMPT",
        description: "Le message ne peut pas être vide.",
        code: "ERR_APPLE_AI_INVALID_PROMPT"
      )
    }

    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      break
    case .unavailable(let reason):
      throw Exception(
        name: "ERR_APPLE_AI_UNAVAILABLE",
        description: Self.message(for: reason),
        code: "ERR_APPLE_AI_UNAVAILABLE"
      )
    }

    let session = LanguageModelSession(
      model: model,
      instructions: """
      Tu es l'assistant local d'une app de to-do list iPhone.
      Réponds toujours en français. Sois naturel et décontracté.

      Tu dois décider s'il faut répondre ou déclencher des actions locales.
      Les seules actions autorisées sont : none, create, edit, delete, complete.
      
      Règles d'action :
      - create : nécessite "title"
      - edit, delete, complete : nécessitent "taskIndex" (index commençant à 1)
      - none : aucune action
      
      La sortie doit contenir :
      - assistantMessage : ta réponse naturelle
      - operations : une liste d'opérations (max 10)
      """
    )

    let response = try await session.respond(
      to: """
      Demande utilisateur:
      \(trimmedInput)

      Tâches actuelles:
      \(formatTasksForDecision(tasks))
      """,
      generating: AppleAIPlannedResponse.self,
      options: GenerationOptions(temperature: 0.75)
    )

    let content = response.content
    let assistantMessage = content.assistantMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    let operations = Array(content.operations.prefix(10)).map { operation in
      [
        "action": normalizeAction(operation.action),
        "taskIndex": operation.taskIndex,
        "title": operation.title?.trimmingCharacters(in: .whitespacesAndNewlines)
      ]
    }

    let finalMessage: String
    if shouldFallbackToDirectReply(assistantMessage) {
      finalMessage = try await generateFallbackReply(input: trimmedInput, tasks: tasks)
    } else {
      finalMessage = assistantMessage
    }

    return [
      "assistantMessage": finalMessage,
      "operations": operations
    ]
#else
    throw Exception(
      name: "ERR_APPLE_AI_UNAVAILABLE",
      description: "Le framework Foundation Models n'est pas disponible avec cette version de Xcode.",
      code: "ERR_APPLE_AI_UNAVAILABLE"
    )
#endif
  }

  private static func buildSummaryPrompt(from tasks: [AppleAITaskRecord]) -> String {
    """
    Fais un vrai résumé naturel de la liste de tâches suivante.
    Tu peux reformuler, regrouper les idées, souligner ce qui ressort le plus et mentionner les éventuels points d'attention.
    Le résultat doit être utile, agréable à lire et pas télégraphique.

    Tâches:
    \(formatTasks(tasks))
    """
  }

  private static func buildPrioritiesPrompt(from tasks: [AppleAITaskRecord]) -> String {
    """
    À partir de la liste de tâches suivante, propose les 3 priorités les plus pertinentes pour aujourd'hui.
    Présente-les de façon naturelle, comme si tu conseillais directement l'utilisateur.
    Favorise les tâches non terminées, concrètes et à fort impact.

    Tâches:
    \(formatTasks(tasks))
    """
  }

  private static func buildRewritePrompt(for title: String) -> String {
    """
    Reformule cette tâche de façon plus claire, plus naturelle et plus agréable à lire.
    Garde une tournure actionnable.

    Tâche:
    \(title.trimmingCharacters(in: .whitespacesAndNewlines))
    """
  }

  private static func formatTasks(_ tasks: [AppleAITaskRecord]) -> String {
    if tasks.isEmpty {
      return "- Aucune tâche"
    }

    return tasks
      .sorted {
        if $0.completed != $1.completed {
          return $0.completed == false
        }
        return $0.createdAt > $1.createdAt
      }
      .map { task in
        let status = task.completed ? "[x]" : "[ ]"
        return "\(status) \(task.title)"
      }
      .joined(separator: "\n")
  }

  private static func formatTasksForDecision(_ tasks: [AppleAITaskRecord]) -> String {
    if tasks.isEmpty {
      return "Aucune tâche."
    }

    return tasks.enumerated().map { index, task in
      let status = task.completed ? "faite" : "à faire"
      return "\(index + 1). [\(status)] \(task.title)"
    }
    .joined(separator: "\n")
  }

  private static func normalizeAction(_ action: String) -> String {
    switch action {
    case "create", "edit", "delete", "complete", "none":
      return action
    default:
      return "none"
    }
  }

  private static func shouldFallbackToDirectReply(_ message: String) -> Bool {
    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return true
    }

    let lowered = trimmed.lowercased()
    return lowered == "voici un résumé de tes tâches :"
      || lowered == "voici un résumé de tes taches :"
      || lowered.hasSuffix(":")
  }

  private static func generateFallbackReply(input: String, tasks: [AppleAITaskRecord]) async throws -> String {
    try await generateText(
      prompt: """
      Réponds à ce message utilisateur de façon naturelle, complète et utile.
      Ne fais pas d'introduction vide.
      Si l'utilisateur demande un résumé, donne directement le résumé.
      Si l'utilisateur demande une reformulation, donne directement la reformulation.
      Garde un ton cool, humain et légèrement familier.
      Tu peux développer un peu si ça rend la réponse meilleure.

      Message utilisateur:
      \(input)

      Tâches actuelles:
      \(formatTasksForDecision(tasks))
      """,
            instructions: """
      Tu es un assistant de to-do list.
      Réponds toujours en français. Sois naturel et décontracté.
      """
    )
  }

  private static func message(for error: Error) -> String {
#if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      if let generationError = error as? LanguageModelSession.GenerationError {
        return generationError.errorDescription
          ?? generationError.failureReason
          ?? generationError.recoverySuggestion
          ?? "La génération locale a échoué."
      }
    }
#endif

    if let localizedError = error as? LocalizedError {
      return localizedError.errorDescription
        ?? localizedError.failureReason
        ?? localizedError.recoverySuggestion
        ?? error.localizedDescription
    }

    return error.localizedDescription
  }

#if canImport(FoundationModels)
  @available(iOS 26.0, *)
  private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
    switch reason {
    case .deviceNotEligible:
      return "Cet appareil n'est pas compatible avec Apple Intelligence."
    case .appleIntelligenceNotEnabled:
      return "Apple Intelligence doit être activé sur l'iPhone."
    case .modelNotReady:
      return "Le modèle Apple local n'est pas encore prêt sur cet appareil."
    @unknown default:
      return "Apple Intelligence n'est pas disponible sur cet appareil pour une raison inconnue."
    }
  }
#endif
}
