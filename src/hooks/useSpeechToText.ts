import { useEffect, useRef, useState } from 'react';
import { Platform } from 'react-native';

import {
  APPLE_SPEECH_DEV_BUILD_MESSAGE,
  addSpeechToTextListener,
  isSpeechToTextSupported,
  requestSpeechToTextPermissions,
  startSpeechToText,
  stopSpeechToText,
  type SpeechToTextErrorEvent,
  type SpeechToTextStartOptions,
  type SpeechToTextState,
} from '../modules/apple-speech';

type UseSpeechToTextOptions = {
  locale?: string;
  onTextChange?: (text: string) => void;
};

type UseSpeechToTextResult = {
  state: SpeechToTextState;
  transcript: string;
  error: string | null;
  isAvailable: boolean;
  isListening: boolean;
  canStart: boolean;
  start: () => Promise<void>;
  stop: () => Promise<void>;
  resetError: () => void;
};

const DEFAULT_LOCALE = 'fr-FR';

function getErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  return 'Une erreur inconnue a interrompu la saisie vocale.';
}

function getFriendlyError(event: SpeechToTextErrorEvent): string {
  switch (event.code) {
    case 'ERR_MICROPHONE_PERMISSION_DENIED':
      return 'Le microphone est refuse. Active-le dans les reglages iOS.';
    case 'ERR_SPEECH_PERMISSION_DENIED':
      return 'La reconnaissance vocale est refusee. Active-la dans les reglages iOS.';
    case 'ERR_SPEECH_RECOGNIZER_UNAVAILABLE':
      return 'La reconnaissance vocale Apple est indisponible pour le moment.';
    case 'ERR_SPEECH_UNSUPPORTED_LOCALE':
      return "La langue choisie n'est pas prise en charge.";
    case 'ERR_SPEECH_ALREADY_RUNNING':
      return 'Une ecoute est deja en cours.';
    case 'ERR_AUDIO_INTERRUPTED':
      return "L'audio a ete interrompu. Reessaie quand l'app reprend la main.";
    default:
      return event.message || 'La saisie vocale a echoue.';
  }
}

export function useSpeechToText(
  options: UseSpeechToTextOptions = {},
): UseSpeechToTextResult {
  const locale = options.locale ?? DEFAULT_LOCALE;
  const onTextChangeRef = useRef(options.onTextChange);
  const [state, setState] = useState<SpeechToTextState>('idle');
  const [transcript, setTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);
  const transcriptRef = useRef('');
  const requestedStopRef = useRef(false);

  onTextChangeRef.current = options.onTextChange;

  useEffect(() => {
    if (!isSpeechToTextSupported()) {
      setError(
        Platform.OS === 'ios'
          ? APPLE_SPEECH_DEV_BUILD_MESSAGE
          : 'La saisie vocale Apple est disponible uniquement sur iOS.',
      );
      return;
    }

    const partialSubscription = addSpeechToTextListener('onPartialResult', (event) => {
      transcriptRef.current = event.text;
      setTranscript(event.text);
      onTextChangeRef.current?.(event.text);
    });

    const finalSubscription = addSpeechToTextListener('onFinalResult', (event) => {
      transcriptRef.current = event.text;
      setTranscript(event.text);
      onTextChangeRef.current?.(event.text);
    });

    const errorSubscription = addSpeechToTextListener('onError', (event) => {
      setError(getFriendlyError(event));
      setState('error');
    });

    const stateSubscription = addSpeechToTextListener('onStateChange', (event) => {
      setState(event.state);

      if (event.state === 'listening') {
        requestedStopRef.current = false;
        setError(null);
      }

      if (event.state === 'idle' && requestedStopRef.current) {
        requestedStopRef.current = false;
      }
    });

    return () => {
      partialSubscription.remove();
      finalSubscription.remove();
      errorSubscription.remove();
      stateSubscription.remove();
    };
  }, []);

  const start = async () => {
    if (!isSpeechToTextSupported()) {
      setError(
        Platform.OS === 'ios'
          ? APPLE_SPEECH_DEV_BUILD_MESSAGE
          : 'La saisie vocale Apple est disponible uniquement sur iOS.',
      );
      return;
    }

    try {
      const permissions = await requestSpeechToTextPermissions();

      if (!permissions.microphone) {
        setError('Le microphone est refuse. Active-le dans les reglages iOS.');
        return;
      }

      if (!permissions.speech) {
        setError('La reconnaissance vocale est refusee. Active-la dans les reglages iOS.');
        return;
      }

      setError(null);
      const nextOptions: SpeechToTextStartOptions = {
        locale,
        reportPartialResults: true,
      };
      await startSpeechToText(nextOptions);
    } catch (startError) {
      setState('error');
      setError(getErrorMessage(startError));
    }
  };

  const stop = async () => {
    requestedStopRef.current = true;

    try {
      await stopSpeechToText();
      setState('idle');
    } catch (stopError) {
      setState('error');
      setError(getErrorMessage(stopError));
    }
  };

  return {
    state,
    transcript,
    error:
      error ??
      (Platform.OS === 'ios' && !isSpeechToTextSupported()
        ? APPLE_SPEECH_DEV_BUILD_MESSAGE
        : null),
    isAvailable: isSpeechToTextSupported(),
    isListening: state === 'listening',
    canStart: isSpeechToTextSupported() && state !== 'listening',
    start,
    stop,
    resetError: () => {
      setError(null);
      if (state === 'error') {
        setState('idle');
      }
    },
  };
}
