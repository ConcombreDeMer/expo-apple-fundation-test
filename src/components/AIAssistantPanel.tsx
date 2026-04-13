import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import {
  getAppleAIAvailability,
  runAppleAIAssistant,
  type AppleAITaskAction,
} from '../modules/apple-ai';
import { Task } from '../types/task';

type AIAssistantPanelProps = {
  tasks: Task[];
  onApplyAction: (action: AppleAITaskAction) => string;
};

export function AIAssistantPanel({ tasks, onApplyAction }: AIAssistantPanelProps) {
  const [prompt, setPrompt] = useState('');
  const [result, setResult] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [availabilityMessage, setAvailabilityMessage] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    const checkAvailability = async () => {
      const availability = await getAppleAIAvailability();
      setAvailabilityMessage(availability.isAvailable ? null : availability.reason);
    };

    void checkAvailability();
  }, []);

  const handleSubmit = async () => {
    setIsLoading(true);
    setErrorMessage(null);

    try {
      const response = await runAppleAIAssistant(prompt, tasks);
      if (response.action) {
        onApplyAction(response.action);
      }
      setResult(response.message);
      setPrompt('');
    } catch (error) {
      const message =
        error instanceof Error ? error.message : "L'assistant local n'a pas pu répondre.";
      setErrorMessage(message);
    } finally {
      setIsLoading(false);
    }
  };

  const isUnavailable = availabilityMessage !== null;

  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <View>
          <Text style={styles.title}>Assistant local</Text>
          <Text style={styles.subtitle}>Décris ce que tu veux faire, il décide et agit</Text>
        </View>
        {isLoading ? <ActivityIndicator size="small" color="#0F172A" /> : null}
      </View>

      <TextInput
        value={prompt}
        onChangeText={setPrompt}
        placeholder='Ex. ajoute appeler Marie demain, marque le devis comme fait, résume ma liste'
        placeholderTextColor="#94A3B8"
        multiline
        textAlignVertical="top"
        style={styles.input}
        editable={!isLoading && !isUnavailable}
      />

      {availabilityMessage ? (
        <Text style={styles.infoText}>{availabilityMessage}</Text>
      ) : null}
      {errorMessage ? <Text style={styles.errorText}>{errorMessage}</Text> : null}

      <Pressable
        onPress={() => void handleSubmit()}
        disabled={isLoading || isUnavailable}
        style={({ pressed }) => [
          styles.submitButton,
          (isLoading || isUnavailable) && styles.submitButtonDisabled,
          pressed && !isLoading && !isUnavailable && styles.pressed,
        ]}
      >
        <Text style={styles.submitButtonText}>Envoyer</Text>
      </Pressable>

      <View style={styles.resultCard}>
        <Text style={styles.resultLabel}>Résultat</Text>
        <Text style={styles.resultText}>
          {result || "Les réponses locales de l'assistant apparaîtront ici."}
        </Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    marginTop: 24,
    padding: 16,
    borderRadius: 20,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 14,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    color: '#0F172A',
  },
  subtitle: {
    marginTop: 4,
    fontSize: 13,
    color: '#64748B',
  },
  input: {
    minHeight: 96,
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#E2E8F0',
    backgroundColor: '#F8FAFC',
    fontSize: 15,
    lineHeight: 21,
    color: '#0F172A',
  },
  submitButton: {
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 48,
    borderRadius: 14,
    backgroundColor: '#0F172A',
  },
  submitButtonDisabled: {
    backgroundColor: '#CBD5E1',
  },
  submitButtonText: {
    fontSize: 15,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  infoText: {
    fontSize: 14,
    color: '#9A3412',
    lineHeight: 20,
  },
  errorText: {
    fontSize: 14,
    color: '#B91C1C',
    lineHeight: 20,
  },
  resultCard: {
    padding: 14,
    borderRadius: 14,
    backgroundColor: '#F8FAFC',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    gap: 8,
  },
  resultLabel: {
    fontSize: 13,
    fontWeight: '700',
    color: '#475569',
    textTransform: 'uppercase',
    letterSpacing: 0.6,
  },
  resultText: {
    fontSize: 15,
    lineHeight: 22,
    color: '#0F172A',
  },
  pressed: {
    opacity: 0.82,
  },
});
