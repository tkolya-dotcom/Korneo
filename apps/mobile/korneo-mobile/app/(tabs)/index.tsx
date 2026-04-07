import React from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import { Link, router } from 'expo-router';
import { useAuth } from '../../src/context/AuthContext';
import { UserRole } from '../../../packages/domain/types';

export default function Dashboard() {
  const { session, signOut } = useAuth();

  const roleLabel = session?.role === 'manager' ? 'Руководитель' :
    session?.role === 'engineer' ? 'Инженер' : 'Исполнитель';

  const navigateTo = (screen: string) => {
    router.push(`/${screen}`);
  };

  return (
    <View className="flex-1 bg-primary p-6 space-y-6">
      {/* Header */}
      <View className="items-center space-y-2">
        <Text className="text-3xl font-orbitron text-accent title-glow">
          КОРНЕО
        </Text>
        <Text className="text-text-muted">
          {session?.name} ({roleLabel})
        </Text>
      </View>

      {/* Stats Grid */}
      <View className="grid grid-cols-2 gap-4">
        <TouchableOpacity className="bg-gradient-card p-6 rounded-xl border border-border shadow-card hover:shadow-glow-cyan" onPress={() => navigateTo('tasks')}>
          <Text className="text-2xl font-orbitron text-accent text-center mb-2">📋</Text>
          <Text className="text-text-muted text-sm text-center">Задачи</Text>
        </TouchableOpacity>
        <TouchableOpacity className="bg-gradient-card p-6 rounded-xl border border-border shadow-card hover:shadow-glow-green" onPress={() => navigateTo('installations')}>
          <Text className="text-2xl font-orbitron text-accent-2 text-center mb-2">⚙</Text>
          <Text className="text-text-muted text-sm text-center">Монтажи</Text>
        </TouchableOpacity>
        <TouchableOpacity className="bg-gradient-card p-6 rounded-xl border border-border shadow-card hover:shadow-glow-cyan" onPress={() => navigateTo('avr')}>
          <Text className="text-2xl font-orbitron text-accent text-center mb-2">📋</Text>
          <Text className="text-text-muted text-sm text-center">АВР</Text>
        </TouchableOpacity>
        <TouchableOpacity className="bg-gradient-card p-6 rounded-xl border border-border shadow-card" onPress={() => router.push('/(tabs)/profile')}>
          <Text className="text-2xl font-orbitron text-accent text-center mb-2">👤</Text>
          <Text className="text-text-muted text-sm text-center">Профиль</Text>
        </TouchableOpacity>
      </View>

      {/* Quick Actions */}
      <View className="space-y-3">
        <TouchableOpacity className="bg-gradient-to-r from-accent to-glow p-4 rounded-lg items-center" onPress={() => router.push('/map')}>
          <Text className="text-primary font-orbitron font-semibold text-lg">🗺️ Карта</Text>
        </TouchableOpacity>
        {session?.role === 'manager' && (
          <TouchableOpacity className="bg-gradient-to-r from-warning to-orange-500 p-4 rounded-lg items-center" onPress={() => router.push('/users')}>
            <Text className="text-primary font-orbitron font-semibold text-lg">👥 Пользователи</Text>
          </TouchableOpacity>
        )}
      </View>

      {/* Logout */}
      <TouchableOpacity
        className="bg-danger/20 border border-danger p-4 rounded-lg items-center mt-8"
        onPress={signOut}
      >
        <Text className="text-danger font-semibold">Выход</Text>
      </TouchableOpacity>
    </View>
  );
}

