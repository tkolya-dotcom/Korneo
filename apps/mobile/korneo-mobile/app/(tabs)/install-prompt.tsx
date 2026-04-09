'use client';

import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity, Platform, Alert } from 'react-native';
import * as Application from 'expo-application';

export default function InstallPrompt() {
  const [deferredPrompt, setDeferredPrompt
