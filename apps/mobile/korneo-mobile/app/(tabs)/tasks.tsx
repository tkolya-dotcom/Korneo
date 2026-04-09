import React, { useState } from 'react';
import { View, Text, FlatList, TouchableOpacity, ActivityIndicator, RefreshControl } from 'react-native';
import { Link } from 'expo-router';
import { useAuth } from '../../../src/context/AuthContext';
import { TaskStatus } from '../../../../packages/domain/types';
import { useTasks } from '../../../src/hooks/useTasks';

export default function TasksScreen() {
  const [statusFilter, setStatusFilter] = useState<TaskStatus>('all');
  const { session } = useAuth();
  const userId = session?.role === 'worker' ? session.id : undefined;
  const { data, isLoading, error, refetch } = useTasks(statusFilter, userId);

  if (error) {
    return (
      <View className="flex-1 bg-primary justify-center items-center p-8">
        <Text className="text-accent text-xl mb-4">Ошибка загрузки</Text>
        <TouchableOpacity className="bg-accent p-4 rounded-lg" onPress={() => refetch()}>
          <Text className="text-primary font-semibold">Повторить</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const tasks = data?.tasks || [];


  const renderTask = ({ item }: any) => (
    <Link href={`/ (tabs)/tasks/${item.id}`} asChild>
      <TouchableOpacity className="bg-gradient-card p-4 mb-3 rounded-xl border border-border shadow-card">
        <View className="flex-row justify-between items-start mb-2">
          <Text className="text-lg font-orbitron text-accent font-semibold">
            #{item.short_id} {item.title}
          </Text>
          <View className={`px-3 py-1 rounded-full bg-opacity-20 ${
            item.status === 'new' ? 'bg-green' : 
            item.status === 'in_progress' ? 'bg-yellow' : 'bg-blue'
          }`}>
            <Text className="font-semibold text-xs uppercase">
              {item.status === 'new' ? 'NEW' : item.status === 'in_progress' ? 'В РАБОТЕ' : 'СДЕЛАНО'}
            </Text>
          </View>
        </View>
        <Text className="text-text-muted text-sm">
          {new Date(item.created_at).toLocaleDateString('ru-RU')}
        </Text>
      </TouchableOpacity>
    </Link>
  );

  return (
    <View className="flex-1 bg-primary p-6">
      <Text className="text-2xl font-orbitron text-accent mb-6">Задачи ({data?.total || 0})</Text>

      <View className="flex-row space-x-2 mb-6">
        {(['all', 'new', 'in_progress', 'done'] as const).map((status) => (
          <TouchableOpacity
            key={status}
            className={`px-4 py-2 rounded-full ${statusFilter === status ? 'bg-accent text-primary' : 'bg-secondary text-accent'}`}
            onPress={() => setStatusFilter(status)}
          >
            <Text className="font-semibold text-sm">
              {status === 'all' ? 'Все' : status.toUpperCase()}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <FlatList
        data={tasks}
        renderItem={renderTask}
        keyExtractor={(item) => item.id}
        refreshControl={
          <RefreshControl refreshing={isLoading} onRefresh={refetch} colors={['#00D9FF']} />
        }
        showsVerticalScrollIndicator={false}
        estimatedItemSize={100}
      />
    </View>
  );
}

