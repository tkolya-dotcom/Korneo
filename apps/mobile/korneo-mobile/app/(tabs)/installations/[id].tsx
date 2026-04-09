import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, ActivityIndicator, ScrollView, Alert } from 'react-native';
import { useLocalSearchParams, router } from 'expo-router';
import { useAuth } from '../../../../src/context/AuthContext';
import { fetchInstallations } from '../../../../../packages/api/supabase';
import { InstallationStatus } from '../../../../../packages/domain/types';
import { supabase } from '../../../../src/config/supabase';

export default function InstallationDetail() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { session } = useAuth();
  const [installation, setInstallation] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);

  useEffect(() => {
    if (id) fetchInstallationDetail();
  }, [id]);

  const fetchInstallationDetail = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('installations')
        .select(`
          *,
          assignee:users(name, role),
          sk_data:sk_data(*)
        `)
        .eq('id', id as string)
        .single();
      if (error) throw error;
      setInstallation(data);
    } catch (error) {
      console.error('Installation error:', error);
      Alert.alert('Ошибка', 'Монтаж не найден');
      router.back();
    } finally {
      setLoading(false);
    }
  };

  const handleStatusChange = async (newStatus: InstallationStatus) => {
    if (!installation) return;
    setUpdating(true);
    try {
      const { error } = await supabase
        .from('installations')
        .update({ status: newStatus })
        .eq('id', installation.id);
      if (error) throw error;
      setInstallation({ ...installation, status: newStatus });
      Alert.alert('Успех', `Статус: ${newStatus}`);
    } catch (error) {
      Alert.alert('Ошибка', 'Не удалось обновить');
    } finally {
      setUpdating(false);
    }
  };

  if (loading) return <ActivityIndicator size="large" className="flex-1 justify-center" />;

  if (!installation) return (
    <View className="flex-1 justify-center items-center bg-primary">
      <Text className="text-text-muted">Монтаж не найден</Text>
    </View>
  );

  return (
    <ScrollView className="flex-1 bg-primary p-6 space-y-6">
      <View className="items-center pb-4 border-b border-border">
        <Text className="text-2xl font-orbitron text-accent">Монтаж #{installation.short_id}</Text>
        <Text className={`text-lg px-4 py-1 rounded-full mt-2 bg-progress`}>{installation.status}</Text>
      </View>

      <View className="space-y-4">
        <View className="bg-gradient-card p-6 rounded-xl">
          <Text className="text-xl font-semibold text-text mb-2">{installation.title}</Text>
          <Text className="text-text-muted mb-4">{installation.address}</Text>
          <Text className="text-sm text-accent">Плановый: {installation.scheduled_at}</Text>
        </View>

        <View className="bg-gradient-card p-4 rounded-xl">
          <Text className="font-semibold text-text mb-2">СК данные</Text>
          {installation.sk_data?.map((sk: any) => (
            <View key={sk.id_sk} className="flex-row justify-between p-3 bg-input rounded-lg mb-2">
              <Text className="text-text">{sk.naimenovanie} ({sk.tip_sk})</Text>
              <Text className={`font-semibold ${sk.status === 'done' ? 'text-green-400' : 'text-yellow-400'}`}>
                {sk.status}
              </Text>
            </View>
          ))}
        </View>

        <View className="space-y-2">
          <Text className="font-semibold text-text mb-2">Действия</Text>
          <View className="flex-row gap-2 flex-wrap">
            {(['new', 'planned', 'in_progress', 'done'] as InstallationStatus[]).map(status => (
              <TouchableOpacity
                key={status}
                className={`px-4 py-2 rounded-lg ${installation.status === status ? 'bg-accent' : 'bg-gradient-card'}`}
                onPress={() => handleStatusChange(status)}
                disabled={updating}
              >
                <Text className={`font-semibold ${installation.status === status ? 'text-primary' : 'text-text'}`}>
                  {status}
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      </View>
    </ScrollView>
  );
}

