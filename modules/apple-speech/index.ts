import { requireOptionalNativeModule } from 'expo-modules-core';

export type AppleSpeechPermissions = {
  microphone: boolean;
  speech: boolean;
};

export type AppleSpeechState = 'idle' | 'listening' | 'error';

export type AppleSpeechStartOptions = {
  locale?: string;
  reportPartialResults?: boolean;
};

export type AppleSpeechStateChangeEvent = {
  state: AppleSpeechState;
  locale: string | null;
};

export type AppleSpeechResultEvent = {
  text: string;
  isFinal: boolean;
  locale: string | null;
};

export type AppleSpeechErrorEvent = {
  code: string;
  message: string;
};

export type AppleSpeechEvents = {
  onPartialResult: (event: AppleSpeechResultEvent) => void;
  onFinalResult: (event: AppleSpeechResultEvent) => void;
  onError: (event: AppleSpeechErrorEvent) => void;
  onStateChange: (event: AppleSpeechStateChangeEvent) => void;
};

export type AppleSpeechNativeModule = {
  requestPermissions(): Promise<AppleSpeechPermissions>;
  startTranscription(options?: AppleSpeechStartOptions): Promise<void>;
  stopTranscription(): Promise<void>;
} & {
  addListener<EventName extends keyof AppleSpeechEvents>(
    eventName: EventName,
    listener: AppleSpeechEvents[EventName],
  ): { remove: () => void };
};

const AppleSpeechModule =
  requireOptionalNativeModule<AppleSpeechNativeModule>('AppleSpeechExpoModule');

export function hasAppleSpeechNativeModule(): boolean {
  return AppleSpeechModule != null;
}

export default AppleSpeechModule;
