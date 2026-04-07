import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, ActivityIndicator, ScrollView, Alert } from 'react-native';
import { useLocalSearchParams, router } from 'expo-router';
import { useAuth } from '../../../../src/context/AuthContext';
import { fetchAvrTasks, updateTaskStatus } from '../../../../../packages/api/supabase';
import { TaskStatus } from '../../../../../packages/domain/types';
import { supabase } from '../../../../src/config/supabase';

export default function AvrDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { session } = useAuth();
  const [avr, setAvr] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);

  useEffect(() => {
    if (id) fetchAvrDetail();
  }, [id]);

  const fetchAvrDetail = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('tasks_avr') // or tasks with avr_type
        .select(`
          *,
          assignee:users(name, role)
        `)
        .eq('id', id as string)
        .single();
      if (error) throw error;
      setAvr(data);
    } catch (error) {
      console.error('AVR detail error:', error);
      Alert.alert('Ошибка', 'АВР не найден');
      router.back();
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (newStatus: TaskStatus) => {
    if (!avr) return;
    setUpdating(true);
    try {
      const success = await updateTaskStatus(avr.id, newStatus);
      if (success) {
        setAvr({ ...avr, status: newStatus });
        Alert.alert('Успех', `Статус изменен на ${newStatus}`);
      }
    } catch (error) {
      Alert.alert('Ошибка', 'Не удалось обновить');
    } finally {
      setUpdating(false);
    }
  };

  if (loading) return <ActivityIndicator size="large" className="flex-1 justify-center" />;

  if (!avr) return (
    <View className="flex-1 justify-center items-center bg-primary">
      <Text className="text-text-muted">АВР не найден</Text>
    </View>
  );

  return (
    <ScrollView className="flex-1 bg-primary p-6 space-y-6">
      <View className="items-center pb-4 border-b border-border">
        <Text className="text-2xl font-orbitron text-accent title-glow">АВР #{avr.short_id}</Text>
        <Text className={`text-lg font-semibold px-4 py-1 rounded-full mt-2 bg-${avr.status}`}>
          {avr.status?.toUpperCase()}
        </Text>
      </View>

      <View className="space-y-4">
        <View className="bg-gradient-card p-6 rounded-xl border border-border">
          <Text className="text-xl font-semibold text-text mb-2">{avr.title}</Text>
          <Text className="text-text-muted">{avr.description || 'AVR/НРД'}</Text>
          {avr.address && <Text className="text-accent mt-2">Адрес: {avr.address}</Text>}
        </View>

        {avr.assignee && (
          <View className="bg-gradient-card p-4 rounded-xl">
            <Text className="font-semibold text-text">Назначено</Text>
            <Text className="text-accent">{avr.assignee.name}</Text>
          </View>
        )}

        <View className="space-y-2">
          <Text className="font-semibold text-text mb-2">Статус</Text>
          <View className="flex-row gap-2 flex-wrap">
            {(['new', 'in_progress', 'waiting_materials', 'done'] as TaskStatus[]).map(status => (
              <TouchableOpacity
                key={status}
                className={`px-4 py-2 rounded-lg ${avr.status === status ? 'bg-accent text-primary' : 'bg-gradient-card'}`}
                onPress={() => handleStatusChange(status)}
                disabled={updating}
              >
                <Text className="font-semibold">{status.replace('_', ' ')}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      </View>
    </ScrollView>
  );
}

