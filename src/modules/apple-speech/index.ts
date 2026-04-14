import { Platform } from 'react-native';

import NativeAppleSpeech, {
  hasAppleSpeechNativeModule,
  type AppleSpeechErrorEvent,
  type AppleSpeechEvents,
  type AppleSpeechPermissions,
  type AppleSpeechResultEvent,
  type AppleSpeechStartOptions,
  type AppleSpeechState,
  type AppleSpeechStateChangeEvent,
} from '../../../modules/apple-speech';

export const APPLE_SPEECH_DEV_BUILD_MESSAGE =
  'La saisie vocale Apple requiert un development build Expo ou un build iOS natif. Expo Go ne charge pas ce module Swift local.';

function getNativeModule() {
  if (Platform.OS !== 'ios') {
    throw new Error('La saisie vocale Apple est disponible uniquement sur iPhone pour le moment.');
  }

  if (!NativeAppleSpeech) {
    throw new Error(APPLE_SPEECH_DEV_BUILD_MESSAGE);
  }

  return NativeAppleSpeech;
}

export type SpeechToTextState = AppleSpeechState;
export type SpeechToTextPermissions = AppleSpeechPermissions;
export type SpeechToTextStartOptions = AppleSpeechStartOptions;
export type SpeechToTextResultEvent = AppleSpeechResultEvent;
export type SpeechToTextStateChangeEvent = AppleSpeechStateChangeEvent;
export type SpeechToTextErrorEvent = AppleSpeechErrorEvent;
export type SpeechToTextEvents = AppleSpeechEvents;

export function isSpeechToTextSupported(): boolean {
  return Platform.OS === 'ios' && hasAppleSpeechNativeModule();
}

export async function requestSpeechToTextPermissions(): Promise<SpeechToTextPermissions> {
  if (Platform.OS !== 'ios') {
    return {
      microphone: false,
      speech: false,
    };
  }

  return getNativeModule().requestPermissions();
}

export async function startSpeechToText(
  options?: SpeechToTextStartOptions,
): Promise<void> {
  return getNativeModule().startTranscription(options);
}

export async function stopSpeechToText(): Promise<void> {
  return getNativeModule().stopTranscription();
}

export function addSpeechToTextListener<EventName extends keyof SpeechToTextEvents>(
  eventName: EventName,
  listener: SpeechToTextEvents[EventName],
) {
  return getNativeModule().addListener(eventName, listener);
}
