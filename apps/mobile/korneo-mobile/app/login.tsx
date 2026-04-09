import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { useAuth } from '../src/context/AuthContext';
import { UserRole } from '../../packages/domain/types';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();
  const { signIn, signUp, session } = useAuth();

  // Redirect if already logged in
  React.useEffect(() => {
    if (session) {
      router.replace('/(tabs)');
    }
  }, [session]);

  const handleSignIn = async () => {
    if (!email || !password) {
      Alert.alert('Ошибка', 'Заполните все поля');
      return;
    }
    setLoading(true);
    try {
      await signIn(email, password);
      router.replace('/(tabs)');
    } catch (error: any) {
      Alert.alert('Ошибка входа', error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSignUp = async () => {
    Alert.alert('Регистрация', 'Доступна только engineer роль. Остальные создаёт manager.');
    // if (!name || !email || !password || role.length < 3) return;
    // try {
    //   await signUp(email, password, name, role as UserRole);
    // } catch (error) {
    //   Alert.alert('Ошибка регистрации', error.message);
    // }
  };

  return (
    <View className="flex-1 bg-primary justify-center p-8">
      <Text className="text-4xl font-orbitron text-accent text-center mb-2 title-glow">
        КОРНЕО
      </Text>
      <Text className="text-text-muted text-center mb-8">
        > Управление задачами_
      </Text>

      <View className="space-y-4">
        <TextInput
          className="bg-secondary p-4 rounded-lg border border-border text-text placeholder-text-muted font-sans text-lg"
          placeholder="Email"
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          autoCapitalize="none"
        />
        <TextInput
          className="bg-secondary p-4 rounded-lg border border-border text-text placeholder-text-muted font-sans text-lg"
          placeholder="Пароль"
          value={password}
          onChangeText={setPassword}
          secureTextEntry
        />
        <TouchableOpacity
          className="bg-gradient-to-r from-accent to-glow p-4 rounded-lg items-center"
          onPress={handleSignIn}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#000" />
          ) : (
            <Text className="text-primary font-orbitron font-semibold text-lg">
              ВОЙТИ
            </Text>
          )}
        </TouchableOpacity>

        <TouchableOpacity
          className="bg-secondary border border-accent p-4 rounded-lg items-center"
          onPress={handleSignUp}
        >
          <Text className="text-accent font-orbitron font-semibold">
            РЕГИСТРАЦИЯ (engineer)
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

