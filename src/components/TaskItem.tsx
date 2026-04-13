import { Pressable, StyleSheet, Text, View } from 'react-native';

import { Task } from '../types/task';

type TaskItemProps = {
  task: Task;
  onToggle: (taskId: string) => void;
  onDelete: (taskId: string) => void;
};

export function TaskItem({ task, onToggle, onDelete }: TaskItemProps) {
  return (
    <View style={styles.card}>
      <Pressable
        onPress={() => onToggle(task.id)}
        style={({ pressed }) => [styles.checkbox, pressed && styles.pressed]}
      >
        <View style={[styles.checkboxInner, task.completed && styles.checkboxChecked]} />
      </Pressable>

      <Pressable
        onPress={() => onToggle(task.id)}
        style={styles.content}
        hitSlop={4}
      >
        <Text style={[styles.title, task.completed && styles.titleCompleted]}>
          {task.title}
        </Text>
      </Pressable>

      <Pressable
        onPress={() => onDelete(task.id)}
        style={({ pressed }) => [styles.deleteButton, pressed && styles.pressed]}
        hitSlop={6}
      >
        <Text style={styles.deleteText}>Supprimer</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    paddingHorizontal: 14,
    borderRadius: 16,
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#0F172A',
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: 12,
  },
  checkboxInner: {
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: 'transparent',
  },
  checkboxChecked: {
    backgroundColor: '#0F172A',
  },
  content: {
    flex: 1,
    marginRight: 12,
  },
  title: {
    fontSize: 16,
    color: '#0F172A',
    lineHeight: 22,
  },
  titleCompleted: {
    color: '#94A3B8',
    textDecorationLine: 'line-through',
  },
  deleteButton: {
    paddingVertical: 6,
    paddingHorizontal: 8,
  },
  deleteText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#DC2626',
  },
  pressed: {
    opacity: 0.7,
  },
});
