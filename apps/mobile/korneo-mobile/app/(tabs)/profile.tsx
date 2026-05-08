import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, ActivityIndicator, Alert, TextInput } from 'react-native';
import { useAuth } from '../../../src/context/AuthContext';
import { getUserProfile } from '../../../../packages/api/supabase';
import { UserRole } from '../../../../packages/domain/types';

export default function Profile() {
  const { session, signOut } = useAuth();
  const [user, setUser] = useState<any>(null);
  const [editing, setEditing] = useState(false);
  const [fcmToken, setFcmToken] = useState('');

  useEffect(() => {
    if (session?.id) {
      getUserProfile(session.id).then(setUser);
    }
  }, [session]);

  const saveFcmToken = async () => {
    if (!session || !fcmToken) return;
    try {
      const { error } = await supabase
        .from('users')
        .update({ fcm_token: fcmToken })
        .eq('id', session.id);
      if (error) throw error;
      Alert.alert('Успех', 'Token сохранен');
    } catch (error) {
      Alert.alert('Ошибка', 'Не удалось сохранить');
    }
    setEditing(false);
  };

  if (!user) return <ActivityIndicator size="large" className="flex-1 justify-center bg-primary" />;

  return (
    <View className="flex-1 bg-primary p-6 space-y-6">
      <View className="items-center space-y-4">
        <View className="w-24 h-24 bg-gradient-card rounded-full items-center justify-center">
          <Text className="text-3xl font-orbitron text-accent">👤</Text>
        </View>
        <Text className="text-2xl font-orbitron text-accent">{user.name}</Text>
        <Text className={`px-4 py-2 rounded-full ${
          user.role === 'manager' ? 'bg-accent' : 'bg-accent-2'
        }`}>
          {user.role?.toUpperCase()}
        </Text>
        <Text className="text-text-muted">{user.email}</Text>
      </View>

      {/* FCM Token */}
      <View className="bg-gradient-card p-6 rounded-xl border border-border">
        <Text className="font-semibold text-text mb-4">FCM Token (Push)</Text>
        {editing ? (
          <View className="space-y-2">
            <TextInput
              className="bg-input border border-border p-3 rounded-lg text-text"
              value={fcmToken}
              onChangeText={setFcmToken}
              multiline
              placeholder="Вставьте FCM token"
            />
            <View className="flex-row gap-2">
              <TouchableOpacity className="flex-1 bg-accent p-3 rounded-lg" onPress={saveFcmToken}>
                <Text className="text-primary font-semibold text-center">Сохранить</Text>
              </TouchableOpacity>
              <TouchableOpacity className="flex-1 bg-muted p-3 rounded-lg" onPress={() => setEditing(false)}>
                <Text className="text-text font-semibold text-center">Отмена</Text>
              </TouchableOpacity>
            </View>
          </View>
        ) : (
          <TouchableOpacity className="flex-row justify-between items-center" onPress={() => setEditing(true)}>
            <Text className="text-text-muted flex-1" numberOfLines={2}>{user.fcm_token || 'Не установлен'}</Text>
            <Text className="text-accent font-semibold">Редактировать</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Settings */}
      <View className="space-y-3">
        <TouchableOpacity className="bg-gradient-card p-4 rounded-lg border border-border">
          <Text className="text-text font-semibold">Уведомления</Text>
          <Text className="text-text-muted text-sm">Push включены</Text>
        </TouchableOpacity>
        <TouchableOpacity className="bg-gradient-card p-4 rounded-lg border border-border">
          <Text className="text-text font-semibold">ATS Creds</Text>
          <Text className="text-text-muted text-sm">Синхронизация с ATS</Text>
        </TouchableOpacity>
      </View>

      <TouchableOpacity
        className="bg-danger/20 border border-danger p-6 rounded-xl items-center mt-auto"
        onPress={signOut}
      >
        <Text className="text-danger font-semibold text-lg">Выход</Text>
      </TouchableOpacity>
    </View>
  );
}

