import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  Keyboard,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  SafeAreaView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import { AIAssistantPanel } from './src/components/AIAssistantPanel';
import { AppleAITaskAction } from './src/modules/apple-ai';
import { TaskItem } from './src/components/TaskItem';
import { Task } from './src/types/task';
import { loadTasks, saveTasks } from './src/utils/storage';

export default function App() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [newTaskTitle, setNewTaskTitle] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [hasHydrated, setHasHydrated] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    const hydrateTasks = async () => {
      try {
        const storedTasks = await loadTasks();
        setTasks(storedTasks);
      } catch (error) {
        console.error('Failed to load tasks', error);
        setErrorMessage('Impossible de charger les tâches.');
      } finally {
        setIsLoading(false);
        setHasHydrated(true);
      }
    };

    void hydrateTasks();
  }, []);

  useEffect(() => {
    if (!hasHydrated) {
      return;
    }

    const persistTasks = async () => {
      try {
        await saveTasks(tasks);
      } catch (error) {
        console.error('Failed to save tasks', error);
        setErrorMessage('Impossible de sauvegarder les tâches.');
      }
    };

    void persistTasks();
  }, [hasHydrated, tasks]);

  const sortedTasks = useMemo(
    () =>
      [...tasks].sort((firstTask, secondTask) => {
        if (firstTask.completed !== secondTask.completed) {
          return Number(firstTask.completed) - Number(secondTask.completed);
        }

        return secondTask.createdAt - firstTask.createdAt;
      }),
    [tasks],
  );

  const handleAddTask = () => {
    const trimmedTitle = newTaskTitle.trim();

    if (!trimmedTitle) {
      return;
    }

    const task: Task = {
      id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      title: trimmedTitle,
      completed: false,
      createdAt: Date.now(),
    };

    setTasks((currentTasks) => [task, ...currentTasks]);
    setNewTaskTitle('');
    setErrorMessage(null);
    Keyboard.dismiss();
  };

  const handleToggleTask = (taskId: string) => {
    setTasks((currentTasks) =>
      currentTasks.map((task) =>
        task.id === taskId ? { ...task, completed: !task.completed } : task,
      ),
    );
    setErrorMessage(null);
  };

  const handleDeleteTask = (taskId: string) => {
    setTasks((currentTasks) => currentTasks.filter((task) => task.id !== taskId));
    setErrorMessage(null);
  };

  const handleAssistantActions = (actions: AppleAITaskAction[]) => {
    setTasks((currentTasks) => {
      let nextTasks = [...currentTasks];

      for (const action of actions.slice(0, 10)) {
        if (action.type === 'create') {
          const newTask: Task = {
            id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
            title: action.title,
            completed: false,
            createdAt: Date.now(),
          };
          nextTasks = [newTask, ...nextTasks];
          continue;
        }

        if (action.type === 'edit') {
          nextTasks = nextTasks.map((task) =>
            task.id === action.taskId ? { ...task, title: action.title } : task,
          );
          continue;
        }

        if (action.type === 'delete') {
          nextTasks = nextTasks.filter((task) => task.id !== action.taskId);
          continue;
        }

        nextTasks = nextTasks.map((task) =>
          task.id === action.taskId ? { ...task, completed: true } : task,
        );
      }

      return nextTasks;
    });
    setErrorMessage(null);
  };

  const pendingTasksCount = tasks.filter((task) => !task.completed).length;

  return (
    <SafeAreaView style={styles.safeArea}>
      <KeyboardAvoidingView
        style={styles.keyboardAvoidingView}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={styles.container}>
          <View style={styles.header}>
            <Text style={styles.title}>To Do List</Text>
            <Text style={styles.subtitle}>
              {pendingTasksCount} tâche{pendingTasksCount > 1 ? 's' : ''} à faire
            </Text>
          </View>

          <View style={styles.inputRow}>
            <TextInput
              value={newTaskTitle}
              onChangeText={setNewTaskTitle}
              placeholder="Ajouter une tâche"
              placeholderTextColor="#94A3B8"
              style={styles.input}
              returnKeyType="done"
              onSubmitEditing={handleAddTask}
              blurOnSubmit={false}
            />
            <Pressable
              onPress={handleAddTask}
              style={({ pressed }) => [
                styles.addButton,
                !newTaskTitle.trim() && styles.addButtonDisabled,
                pressed && newTaskTitle.trim() && styles.addButtonPressed,
              ]}
            >
              <Text style={styles.addButtonText}>Ajouter</Text>
            </Pressable>
          </View>

          {errorMessage ? <Text style={styles.errorText}>{errorMessage}</Text> : null}

          {isLoading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="small" color="#0F172A" />
            </View>
          ) : (
            <FlatList
              data={sortedTasks}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => (
                <TaskItem
                  task={item}
                  onToggle={handleToggleTask}
                  onDelete={handleDeleteTask}
                />
              )}
              contentContainerStyle={[
                styles.listContent,
                sortedTasks.length === 0 && styles.emptyListContent,
              ]}
              keyboardShouldPersistTaps="handled"
              showsVerticalScrollIndicator={false}
              ListEmptyComponent={
                <View style={styles.emptyState}>
                  <Text style={styles.emptyTitle}>Aucune tâche pour le moment</Text>
                  <Text style={styles.emptyDescription}>
                    Ajoute ta première tâche pour commencer.
                  </Text>
                </View>
              }
              ListFooterComponent={
                <AIAssistantPanel
                  tasks={sortedTasks}
                  onApplyActions={handleAssistantActions}
                />
              }
            />
          )}
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#F8FAFC',
  },
  keyboardAvoidingView: {
    flex: 1,
  },
  container: {
    flex: 1,
    paddingHorizontal: 20,
    paddingTop: 12,
    paddingBottom: 20,
  },
  header: {
    marginBottom: 20,
  },
  title: {
    fontSize: 32,
    fontWeight: '700',
    color: '#0F172A',
  },
  subtitle: {
    marginTop: 6,
    fontSize: 15,
    color: '#64748B',
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
    gap: 12,
  },
  input: {
    flex: 1,
    height: 52,
    paddingHorizontal: 16,
    borderRadius: 14,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    fontSize: 16,
    color: '#0F172A',
  },
  addButton: {
    height: 52,
    paddingHorizontal: 18,
    borderRadius: 14,
    backgroundColor: '#0F172A',
    alignItems: 'center',
    justifyContent: 'center',
  },
  addButtonDisabled: {
    backgroundColor: '#CBD5E1',
  },
  addButtonPressed: {
    opacity: 0.86,
  },
  addButtonText: {
    fontSize: 15,
    fontWeight: '600',
    color: '#FFFFFF',
  },
  errorText: {
    marginBottom: 12,
    fontSize: 14,
    color: '#B91C1C',
  },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  listContent: {
    paddingTop: 8,
    paddingBottom: 32,
    gap: 12,
  },
  emptyListContent: {
    flexGrow: 1,
    justifyContent: 'center',
  },
  emptyState: {
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#0F172A',
    marginBottom: 8,
  },
  emptyDescription: {
    fontSize: 14,
    color: '#64748B',
    textAlign: 'center',
    lineHeight: 20,
  },
});
