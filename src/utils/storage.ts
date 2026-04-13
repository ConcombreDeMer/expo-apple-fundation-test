import AsyncStorage from '@react-native-async-storage/async-storage';

import { Task } from '../types/task';

const TASKS_STORAGE_KEY = 'todo.tasks';

export async function loadTasks(): Promise<Task[]> {
  const rawValue = await AsyncStorage.getItem(TASKS_STORAGE_KEY);

  if (!rawValue) {
    return [];
  }

  const parsedValue: unknown = JSON.parse(rawValue);

  if (!Array.isArray(parsedValue)) {
    return [];
  }

  return parsedValue.filter(isTask);
}

export async function saveTasks(tasks: Task[]): Promise<void> {
  await AsyncStorage.setItem(TASKS_STORAGE_KEY, JSON.stringify(tasks));
}

function isTask(value: unknown): value is Task {
  if (!value || typeof value !== 'object') {
    return false;
  }

  const candidate = value as Record<string, unknown>;

  return (
    typeof candidate.id === 'string' &&
    typeof candidate.title === 'string' &&
    typeof candidate.completed === 'boolean' &&
    typeof candidate.createdAt === 'number'
  );
}
