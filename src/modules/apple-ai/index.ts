import { Platform } from 'react-native';

import NativeAppleAI, {
  type AppleAIAvailability,
  type AppleAIPlannedActionNative,
  type AppleAINativeTask,
} from '../../../modules/apple-ai';
import { Task } from '../../types/task';

export const APPLE_AI_DEV_BUILD_MESSAGE =
  "Cette fonctionnalité nécessite un development build Expo ou un build iOS natif. Expo Go ne charge pas le module Swift local.";

export type AppleAITaskAction =
  | { type: 'create'; title: string }
  | { type: 'edit'; taskId: string; title: string }
  | { type: 'delete'; taskId: string }
  | { type: 'complete'; taskId: string };

export type AppleAIAssistantResult = {
  message: string;
  action: AppleAITaskAction | null;
};

function getNativeModule() {
  if (Platform.OS !== 'ios') {
    throw new Error("L'assistant Apple local est disponible uniquement sur iPhone.");
  }

  if (!NativeAppleAI) {
    throw new Error(APPLE_AI_DEV_BUILD_MESSAGE);
  }

  return NativeAppleAI;
}

function mapTask(task: Task): AppleAINativeTask {
  return {
    id: task.id,
    title: task.title,
    completed: task.completed,
    createdAt: task.createdAt,
  };
}

function serializeTasks(tasks: Task[]): string {
  if (tasks.length === 0) {
    return '- Aucune tâche';
  }

  return tasks
    .map((task) => `${task.completed ? '[x]' : '[ ]'} ${task.title}`)
    .join('\n');
}

function withTaskContext(prompt: string, tasks: Task[] = []): string {
  const trimmedPrompt = prompt.trim();

  if (!tasks.length) {
    return trimmedPrompt;
  }

  return `${trimmedPrompt}\n\nContexte utile:\n${serializeTasks(tasks)}`;
}

export async function getAppleAIAvailability(): Promise<AppleAIAvailability> {
  if (Platform.OS !== 'ios') {
    return {
      isAvailable: false,
      reason: "L'assistant Apple local est disponible uniquement sur iPhone.",
    };
  }

  if (!NativeAppleAI) {
    return {
      isAvailable: false,
      reason: APPLE_AI_DEV_BUILD_MESSAGE,
    };
  }

  return NativeAppleAI.getAvailability();
}

export async function isAppleAIAvailable(): Promise<boolean> {
  const availability = await getAppleAIAvailability();
  return availability.isAvailable;
}

export async function generateAppleAIText(
  prompt: string,
  tasks: Task[] = [],
): Promise<string> {
  const trimmedPrompt = prompt.trim();

  if (!trimmedPrompt) {
    throw new Error("Saisis une instruction avant de lancer l'assistant.");
  }

  return getNativeModule().generateText(withTaskContext(trimmedPrompt, tasks));
}

export async function summarizeTasksWithAppleAI(tasks: Task[]): Promise<string> {
  if (tasks.length === 0) {
    return 'Aucune tâche à résumer pour le moment.';
  }

  return getNativeModule().summarizeTasks(tasks.map(mapTask));
}

export async function suggestTaskPrioritiesWithAppleAI(
  tasks: Task[],
): Promise<string> {
  const pendingTasks = tasks.filter((task) => !task.completed);

  if (pendingTasks.length === 0) {
    return 'Aucune tâche en attente. Ajoute quelques tâches pour obtenir des priorités.';
  }

  return getNativeModule().suggestPriorities(pendingTasks.map(mapTask));
}

export async function turnNotesIntoTasksWithAppleAI(
  input: string,
): Promise<string[]> {
  const trimmedInput = input.trim();

  if (!trimmedInput) {
    throw new Error('Ajoute quelques notes avant de demander une transformation.');
  }

  const generatedTasks = await getNativeModule().turnNotesIntoTasks(trimmedInput);

  return generatedTasks.map((task) => task.trim()).filter(Boolean);
}

export async function rewriteTaskWithAppleAI(title: string): Promise<string> {
  const trimmedTitle = title.trim();

  if (!trimmedTitle) {
    throw new Error('La tâche à reformuler ne peut pas être vide.');
  }

  return getNativeModule().rewriteTask(trimmedTitle);
}

function normalizePlannedAction(
  plan: AppleAIPlannedActionNative,
  tasks: Task[],
): AppleAITaskAction | null {
  if (plan.action === 'none') {
    return null;
  }

  if (plan.action === 'create') {
    const title = plan.title?.trim();
    return title ? { type: 'create', title } : null;
  }

  const taskIndex = typeof plan.taskIndex === 'number' ? plan.taskIndex - 1 : -1;
  const targetTask = tasks[taskIndex];

  if (!targetTask) {
    return null;
  }

  if (plan.action === 'edit') {
    const title = plan.title?.trim();
    return title ? { type: 'edit', taskId: targetTask.id, title } : null;
  }

  if (plan.action === 'delete') {
    return { type: 'delete', taskId: targetTask.id };
  }

  if (plan.action === 'complete') {
    return { type: 'complete', taskId: targetTask.id };
  }

  return null;
}

export async function runAppleAIAssistant(
  input: string,
  tasks: Task[],
): Promise<AppleAIAssistantResult> {
  const trimmedInput = input.trim();

  if (!trimmedInput) {
    throw new Error("Saisis un message avant d'envoyer.");
  }

  const plan = await getNativeModule().planAction(
    trimmedInput,
    tasks.map(mapTask),
  );

  return {
    message: plan.assistantMessage.trim(),
    action: normalizePlannedAction(plan, tasks),
  };
}
