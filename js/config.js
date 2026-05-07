
export const SUPABASE_CONFIG = {
  url: 'https://jmxjbdnqnzkzxgsfywha.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpteGpiZG5xbnprenhnc2Z5d2hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNTQ0MzQsImV4cCI6MjA4NjczMDQzNH0.z6y6DGs9Z6kojQYeAdsgKA-m4pxuoeABdY4rAojPEE4',
  serviceRoleKey: 'YOUR_SERVICE_ROLE_KEY_HERE' // РўРѕР»СЊРєРѕ РґР»СЏ СЃРµСЂРІРµСЂР°!
};

export const FIREBASE_CONFIG = {
  apiKey: "AIzaSyAM3t4qBtb2FhUElkWvKbEF4Oui2I9rZGk",
  authDomain: "planner-web-4fec7.firebaseapp.com",
  projectId: "planner-web-4fec7",
  storageBucket: "planner-web-4fec7.firebasestorage.app",
  messagingSenderId: "884674213029",
  appId: "1:884674213029:web:423491ba151fcd0177894c",
  measurementId: "G-FTVNHS8G2Y"
};

export const VAPID_PUBLIC_KEY = 'BDhqTgQRiZ69r0YWz6vw5HIEkecDEqLV9NIGfUEpWaPUFGcc4T_WWlaE8OmSO5EMzvOySOYXdpKtI3J1emZXj0s';

export const MAPBOX_TOKEN = 'pk.eyJ1IjoidGtvbHlhIiwiYSI6ImNtbXZ0eGI1ODJkbnIycXNkMTBteWNvd20ifQ.m0WVg1Ix7RuR3AJyHDHRtg';

export const APP_CONFIG = {
  name: 'РћРћРћ РљРѕСЂРЅРµРѕ - РџР»Р°РЅРёСЂРѕРІС‰РёРє',
  version: '1.0.0',
  
  roles: {
    WORKER: 'worker',
    ENGINEER: 'engineer',
    MANAGER: 'manager',
    DEPUTY_HEAD: 'deputy_head',
    ADMIN: 'admin'
  },
  
  taskStatus: {
    NEW: 'new',
    IN_PROGRESS: 'in_progress',
    ON_HOLD: 'on_hold',
    COMPLETED: 'completed',
    ARCHIVED: 'archived'
  },
  
  installationStatus: {
    NEW: 'new',
    IN_PROGRESS: 'in_progress',
    COMPLETED: 'completed',
    ARCHIVED: 'archived'
  },
  
  requestStatus: {
    PENDING: 'pending',
    APPROVED: 'approved',
    REJECTED: 'rejected',
    ISSUED: 'issued'
  },
  
  chatTypes: {
    PRIVATE: 'private',
    GROUP: 'group',
    JOB: 'job'
  },
  
  priorities: {
    LOW: 'low',
    NORMAL: 'normal',
    HIGH: 'high',
    URGENT: 'urgent'
  },
  
  notifications: {
    checkInterval: 30000, // 30 СЃРµРєСѓРЅРґ
    maxRetries: 3,
    retryDelay: 5000 // 5 СЃРµРєСѓРЅРґ
  },
  
  cache: {
    enabled: true,
    ttl: 300000, // 5 РјРёРЅСѓС‚
    maxSize: 100 // РјР°РєСЃ. РєРѕР»РёС‡РµСЃС‚РІРѕ Р·Р°РїРёСЃРµР№
  }
};

export const API_ENDPOINTS = {
  USERS: '/users',
  USER_BY_ID: (id) => `/users?id=eq.${id}`,
  
  TASKS: '/tasks',
  TASK_BY_ID: (id) => `/tasks?id=eq.${id}`,
  TASKS_BY_ASSIGNEE: (assigneeId) => `/tasks?assignee_id=eq.${assigneeId}`,
  
  PROJECTS: '/projects',
  
  INSTALLATIONS: '/installations',
  
  TASKS_AVR: '/tasks_avr',
  
  CHATS: '/chats',
  MESSAGES: '/messages',
  
  MATERIALS: '/materials',
  MATERIALS_REQUESTS: '/materials_requests',
  
  PURCHASE_REQUESTS: '/purchase_requests'
};

if (typeof window !== 'undefined') {
  window.APP_CONFIG = APP_CONFIG;
  window.SUPABASE_CONFIG = SUPABASE_CONFIG;
  window.FIREBASE_CONFIG = FIREBASE_CONFIG;
  window.VAPID_PUBLIC_KEY = VAPID_PUBLIC_KEY;
  window.MAPBOX_TOKEN = MAPBOX_TOKEN;
}
