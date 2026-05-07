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

  React.useEffect(() => {
    if (session) {
      router.replace('/(tabs)');
    }
  }, [session]);

  const handleSignIn = async () => {
    if (!email || !password) {
      Alert.alert('РћС€РёР±РєР°', 'Р—Р°РїРѕР»РЅРёС‚Рµ РІСЃРµ РїРѕР»СЏ');
      return;
    }
    setLoading(true);
    try {
      await signIn(email, password);
      router.replace('/(tabs)');
    } catch (error: any) {
      Alert.alert('РћС€РёР±РєР° РІС…РѕРґР°', error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSignUp = async () => {
    Alert.alert('Р РµРіРёСЃС‚СЂР°С†РёСЏ', 'Р”РѕСЃС‚СѓРїРЅР° С‚РѕР»СЊРєРѕ engineer СЂРѕР»СЊ. РћСЃС‚Р°Р»СЊРЅС‹Рµ СЃРѕР·РґР°С‘С‚ manager.');
  };

  return (
    <View className="flex-1 bg-primary justify-center p-8">
      <Text className="text-4xl font-orbitron text-accent text-center mb-2 title-glow">
        РљРћР РќР•Рћ
      </Text>
      <Text className="text-text-muted text-center mb-8">
        > РЈРїСЂР°РІР»РµРЅРёРµ Р·Р°РґР°С‡Р°РјРё_
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
          placeholder="РџР°СЂРѕР»СЊ"
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
              Р’РћР™РўР
            </Text>
          )}
        </TouchableOpacity>

        <TouchableOpacity
          className="bg-secondary border border-accent p-4 rounded-lg items-center"
          onPress={handleSignUp}
        >
          <Text className="text-accent font-orbitron font-semibold">
            Р Р•Р“РРЎРўР РђР¦РРЇ (engineer)
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

