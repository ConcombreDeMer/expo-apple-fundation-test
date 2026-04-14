import { requireOptionalNativeModule } from 'expo-modules-core';

export type AppleAINativeTask = {
  id: string;
  title: string;
  completed: boolean;
  createdAt: number;
};

export type AppleAIAvailability = {
  isAvailable: boolean;
  reason: string | null;
};

export type AppleAIPlannedOperationNative = {
  action: 'none' | 'create' | 'edit' | 'delete' | 'complete';
  taskIndex?: number | null;
  title?: string | null;
};

export type AppleAIPlannedActionNative = {
  assistantMessage: string;
  operations: AppleAIPlannedOperationNative[];
};

export type AppleAINativeModule = {
  getAvailability(): Promise<AppleAIAvailability>;
  isAvailable(): Promise<boolean>;
  generateText(prompt: string): Promise<string>;
  summarizeTasks(tasks: AppleAINativeTask[]): Promise<string>;
  suggestPriorities(tasks: AppleAINativeTask[]): Promise<string>;
  turnNotesIntoTasks(input: string): Promise<string[]>;
  rewriteTask(title: string): Promise<string>;
  planAction(input: string, tasks: AppleAINativeTask[]): Promise<AppleAIPlannedActionNative>;
};

export default requireOptionalNativeModule<AppleAINativeModule>('AppleAIExpoModule');
