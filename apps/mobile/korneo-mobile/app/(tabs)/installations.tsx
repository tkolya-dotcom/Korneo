import React, { useState, useEffect } from 'react';
import { View, Text, FlatList, TouchableOpacity, ActivityIndicator } from 'react-native';
import { supabase } from '../../../src/config/supabase';
import { useAuth } from '../../../src/context/AuthContext';
import { InstallationStatus, Installation } from '../../../../packages/domain/types';

export default function InstallationsScreen() {
  const [installations, setInstallations] = useState<Installation[]>([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState<InstallationStatus>('all');
  const { session } = useAuth();

  useEffect(() => {
    fetchInstallations();
  }, [statusFilter]);

  const fetchInstallations = async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('installations')
        .select(`
          *,
          assignee:assignee_id (*)
        `)
        .order('scheduled_at', { ascending: true, nullsFirst: false });

      if (statusFilter !== 'all') {
        query = query.eq('status', statusFilter);
      }

      if (session?.role === 'worker') {
        query = query.eq('assignee_id', session.id);
      }

      const { data, error } = await query;
      if (error) throw error;
      setInstallations(data || []);
    } catch (error) {
      console.error('Installations error:', error);
    } finally {
      setLoading(false);
    }
  };

  const renderInstallation = ({ item }: { item: Installation }) => {
    const skCount = item.sk_data?.filter(sk => sk.status !== 'removed').length || 0;
    
    return (
      <TouchableOpacity className="bg-gradient-card p-5 mb-4 rounded-xl border border-border shadow-card hover:shadow-glow-cyan">
        <View className="flex-row justify-between items-start mb-3">
          <Text className="text-xl font-orbitron text-accent font-bold">
            #{item.short_id} {item.title}
          </Text>
          <View className={`status status-${item.status}`}>
            {item.status === 'new' && 'НОВЫЙ'}
            {item.status === 'planned' && 'ПЛАН'}
            {item.status === 'in_progress' && 'МОНТАЖ'}
            {item.status === 'done' && 'СДАНО'}
          </View>
        </View>
        
        <View className="space-y-1 mb-3">
          <Text className="text-text text-sm">{item.address || 'Адрес не указан'}</Text>
          {item.scheduled_at && (
            <Text className="text-text-muted font-mono text-xs">
              {new Date(item.scheduled_at).toLocaleDateString('ru-RU')}
            </Text>
          )}
          <Text className="text-accent-2 font-mono text-xs">
            СК: {skCount}/7
          </Text>
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <View className="flex-1 bg-primary p-6">
      <Text className="text-2xl font-orbitron text-accent mb-6">Монтажи</Text>

      <View className="flex-row space-x-2 mb-6">
        {(['all', 'new', 'planned', 'in_progress', 'done'] as InstallationStatus[]).map((status) => (
          <TouchableOpacity
            key={status}
            className={`px-4 py-2 rounded-full ${statusFilter === status ? 'bg-accent text-primary' : 'bg-secondary text-accent'}`}
            onPress={() => setStatusFilter(status as InstallationStatus)}
          >
            <Text className="font-semibold text-sm uppercase">
              {status === 'all' ? 'Все' : status.replace('_', ' ').toUpperCase()}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {loading ? (
        <View className="flex-1 justify-center items-center">
          <ActivityIndicator size="large" color="#00D9FF" />
        </View>
      ) : (
        <FlatList
          data={installations}
          renderItem={renderInstallation}
          keyExtractor={(item) => item.id}
          showsVerticalScrollIndicator={false}
        />
      )}
    </View>
  );
}

