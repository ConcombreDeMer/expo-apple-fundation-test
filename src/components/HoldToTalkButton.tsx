import { Pressable, StyleSheet, Text, View } from 'react-native';

import type { SpeechToTextState } from '../modules/apple-speech';

type HoldToTalkButtonProps = {
  disabled?: boolean;
  state: SpeechToTextState;
  onPressIn: () => void;
  onPressOut: () => void;
};

export function HoldToTalkButton({
  disabled = false,
  state,
  onPressIn,
  onPressOut,
}: HoldToTalkButtonProps) {
  const isListening = state === 'listening';
  const isError = state === 'error';

  return (
    <View style={styles.container}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Maintenir pour dicter"
        accessibilityHint="Maintiens le bouton pendant que tu parles, puis relache pour conserver le texte."
        disabled={disabled}
        onPressIn={onPressIn}
        onPressOut={onPressOut}
        style={({ pressed }) => [
          styles.button,
          isListening && styles.buttonListening,
          isError && styles.buttonError,
          disabled && styles.buttonDisabled,
          pressed && !disabled && styles.buttonPressed,
        ]}
      >
        <Text style={styles.icon}>{isListening ? 'REC' : 'Mic'}</Text>
      </Pressable>
      <Text style={[styles.label, isError && styles.labelError]}>
        {isListening ? 'Ecoute...' : isError ? 'Erreur micro' : 'Parler'}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    gap: 6,
  },
  button: {
    width: 52,
    height: 52,
    borderRadius: 26,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#0F172A',
  },
  buttonListening: {
    backgroundColor: '#DC2626',
  },
  buttonError: {
    backgroundColor: '#B91C1C',
  },
  buttonDisabled: {
    backgroundColor: '#CBD5E1',
  },
  buttonPressed: {
    transform: [{ scale: 0.96 }],
  },
  icon: {
    fontSize: 20,
    color: '#FFFFFF',
  },
  label: {
    fontSize: 12,
    color: '#64748B',
  },
  labelError: {
    color: '#B91C1C',
  },
});
