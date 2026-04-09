import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, ActivityIndicator, ScrollView, Alert } from 'react-native';
import { useLocalSearchParams, router } from 'expo-router';
import { useAuth } from '../../../../src/context/AuthContext';
import { fetchTasks, updateTaskStatus } from '../../../../../packages/api/supabase';
import { Task, TaskStatus, UserRole } from '../../../../../packages/domain/types';
import { supabase } from '../../../../src/config/supabase';

export default function TaskDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { session } = useAuth();
  const [task, setTask] = useState<Task | null>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);

  useEffect(() => {
    if (id) fetchTaskDetail();
  }, [id]);

  const fetchTaskDetail = async () => {
    setLoading(true);
    try {
      // Enhanced single task fetch
      const { data, error } = await supabase
        .from('tasks')
        .select(`
          *,
          assignee:users(name, role),
          project:projects(title),
          comments!inner(*)
        `)
        .eq('id', id as string)
        .single();
      if (error) throw error;
      setTask(data as any); // Cast to Task + relations
    } catch (error) {
      console.error('Task detail error:', error);
      Alert.alert('Ошибка', 'Задача не найдена');
      router.back();
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (newStatus: TaskStatus) => {
    if (!task || !session) return;
    setUpdating(true);
    try {
      const success = await updateTaskStatus(task.id, newStatus);
      if (success) {
        setTask({ ...task, status: newStatus });
        Alert.alert('Успех', `Статус изменен на ${newStatus}`);
      } else {
        Alert.alert('Ошибка', 'Не удалось обновить статус');
      }
    } catch (error) {
      Alert.alert('Ошибка', 'Ошибка сервера');
    } finally {
      setUpdating(false);
    }
  };

  if (loading) return <ActivityIndicator size="large" className="flex-1 justify-center" />;

  if (!task) return (
    <View className="flex-1 justify-center items-center bg-primary">
      <Text className="text-text-muted">Задача не найдена</Text>
    </View>
  );

  return (
    <ScrollView className="flex-1 bg-primary p-6 space-y-6">
      {/* Header */}
      <View className="items-center pb-4 border-b border-border">
        <Text className="text-2xl font-orbitron text-accent title-glow">Задача #{task.short_id}</Text>
        <Text className={`text-lg font-semibold px-4 py-1 rounded-full mt-2 ${
          task.status === 'new' ? 'bg-new text-new-text' :
          task.status === 'in_progress' ? 'bg-progress text-accent' :
          task.status === 'done' ? 'bg-done text-done-text' : 'bg-muted'
        }`}>
          {task.status?.toUpperCase()}
        </Text>
      </View>

      {/* Content */}
      <View className="space-y-4">
        <View className="bg-gradient-card p-6 rounded-xl border border-border">
          <Text className="text-xl font-semibold text-text mb-2">{task.title}</Text>
          <Text className="text-text-muted mb-4">{task.description || 'Нет описания'}</Text>
          {task.due_date && (
            <Text className="text-sm text-accent-2">Срок: {new Date(task.due_date).toLocaleDateString()}</Text>
          )}
        </View>

        {task.assignee && (
          <View className="bg-gradient-card p-4 rounded-xl border border-border">
            <Text className="font-semibold text-text">Исполнитель</Text>
            <Text className="text-accent">{task.assignee.name} ({task.assignee.role})</Text>
          </View>
        )}

        {/* Status Actions */}
        <View className="space-y-2">
          <Text className="font-semibold text-text mb-2">Изменить статус</Text>
          <View className="flex-row flex-wrap gap-2">
            {(['new', 'in_progress', 'waiting_materials', 'done'] as TaskStatus[]).map(status => (
              <TouchableOpacity
                key={status}
                className={`px-4 py-2 rounded-lg ${
                  task.status === status ? 'bg-accent text-primary' : 'bg-gradient-card border border-border'
                }`}
                onPress={() => handleStatusChange(status)}
                disabled={updating}
              >
                <Text className="font-semibold">{status.replace('_', ' ').toUpperCase()}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>

        {/* Comments */}
        {task.comments && task.comments.length > 0 && (
          <View className="space-y-2">
            <Text className="font-semibold text-text">Комментарии</Text>
            {task.comments.map((comment: any) => (
              <View key={comment.id} className="bg-gradient-card p-4 rounded-lg border-l-4 border-accent">
                <Text className="font-semibold text-accent">{comment.author_name}</Text>
                <Text className="text-text-muted">{comment.content}</Text>
                <Text className="text-xs text-text-muted mt-1">{new Date(comment.created_at).toLocaleString()}</Text>
              </View>
            ))}
          </View>
        )}
      </View>
    </ScrollView>
  );
}

