import React, { Suspense } from 'react';
import { Stack, useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { View, ActivityIndicator, Text, Alert } from 'react-native';
import { Providers } from '../src/providers';
import { useAuth } from '../src/context/AuthContext';
import NetInfo from '@react-native-async-storage/async-storage'; // Expo NetInfo

function OfflineNotice() {
  return (
    <View className="flex-1 bg-primary justify-center items-center p-8">
      <Text className="text-xl text-accent text-center mb-4">🚫 Нет сети</Text>
      <Text className="text-text-muted text-center">Работает оффлайн с кэшем</Text>
    </View>
  );
}

function RootLayoutNav() {
  const { session, isLoading } = useAuth();
  const router = useRouter();
  const [isOnline, setIsOnline] = useState(true);

  useEffect(() => {
    // Offline detection
    const unsubscribe = NetInfo.addEventListener(state => {
      setIsOnline(state.isConnected ?? false);
    });
    return unsubscribe();
  }, []);

  useEffect(() => {
    if (!isLoading && !session) {
      router.replace('/login');
    }
  }, [session, isLoading]);

  if (!isOnline) {
    return <OfflineNotice />;
  }

  if (isLoading) {
    return (
      <View className="flex-1 bg-primary justify-center items-center">
        <ActivityIndicator size="large" color="#00D9FF" />
      </View>
    );
  }

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="(tabs)" />
      <Stack.Screen name="modal" options={{ presentation: 'modal' }} />
      <Stack.Screen name="login" />
    </Stack>
  );
}

export default function RootLayout() {
  return (
    <Providers>
      <Suspense fallback={<ActivityIndicator size="large" color="#00D9FF" />}>
        <RootLayoutNav />
      </Suspense>
    </Providers>
  );
}


