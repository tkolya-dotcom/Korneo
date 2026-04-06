import { Alert, Linking, Platform } from 'react-native';
import { fetch } from '@react-native-async-storage/async-storage';

export async function checkForUpdate() {
  try
