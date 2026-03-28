/**
 * Конфигурация приложения
 * Все секреты и API ключи
 */

// Supabase конфигурация
export const SUPABASE_CONFIG = {
  url: 'https://jmxjbdnqnzkzxgsfywha.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpteGpiZG5xbnprenhnc2Z5d2hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNTQ0MzQsImV4cCI6MjA4NjczMDQzNH0.z6y6DGs9Z6kojQYeAdsgKA-m4pxuoeABdY4rAojPEE4',
  serviceRoleKey: 'YOUR_SERVICE_ROLE_KEY_HERE' // Только для сервера!
};

// Firebase конфигурация (для Push-уведомлений)
export const FIREBASE_CONFIG = {
  apiKey: "AIzaSyAM3t4qBtb2FhUElkWvKbEF4Oui2I9rZGk",
  authDomain: "planner-web-4fec7.firebaseapp.com",
  projectId: "planner-web-4fec7",
  storageBucket: "planner-web-4fec7.firebasestorage.app",
  messagingSenderId: "884674213029",
  appId: "1:884674213029:web:423491ba151fcd0177894c",
  measurementId: "G-FTVNHS8G2Y"
};

// VAPID ключ для Web Push
export const VAPID_PUBLIC_KEY = 'BDhqTgQRiZ69r0YWz6vw5HIEkecDEqLV9NIGfUEpWaPUFGcc4T_WWlaE8OmSO5EMzvOySOYXdpKtI3J1emZXj0s';

// Mapbox токен (для карт)
export const MAPBOX_TOKEN = 'pk.eyJ1IjoidGtvbHlhIiwiYSI6ImNtbXZ0eGI1ODJkbnIycXNkMTBteWNvd20ifQ.m0WVg1Ix7RuR3AJyHDHRtg';

// Константы приложения
export const APP_CONFIG = {
  name: 'ООО Корнео - Планировщик',
  version: '1.0.0',
  
  // Роли пользователей
  roles: {
    WORKER: 'worker',
    ENGINEER: 'engineer',
    MANAGER: 'manager',
    DEPUTY_HEAD: 'deputy_head',
    ADMIN: 'admin'
  },
  
  // Статусы задач
  taskStatus: {
    NEW: 'new',
    IN_PROGRESS: 'in_progress',
    ON_HOLD: 'on_hold',
    COMPLETED: 'completed',
    ARCHIVED: 'archived'
  },
  
  // Статусы монтажей
  installationStatus: {
    NEW: 'new',
    IN_PROGRESS: 'in_progress',
    COMPLETED: 'completed',
    ARCHIVED: 'archived'
  },
  
  // Статусы заявок на материалы
  requestStatus: {
    PENDING: 'pending',
    APPROVED: 'approved',
    REJECTED: 'rejected',
    ISSUED: 'issued'
  },
  
  // Типы чатов
  chatTypes: {
    PRIVATE: 'private',
    GROUP: 'group',
    JOB: 'job'
  },
  
  // Приоритеты задач
  priorities: {
    LOW: 'low',
    NORMAL: 'normal',
    HIGH: 'high',
    URGENT: 'urgent'
  },
  
  // Настройки уведомлений
  notifications: {
    checkInterval: 30000, // 30 секунд
    maxRetries: 3,
    retryDelay: 5000 // 5 секунд
  },
  
  // Кэширование
  cache: {
    enabled: true,
    ttl: 300000, // 5 минут
    maxSize: 100 // макс. количество записей
  }
};

// URL и эндпоинты
export const API_ENDPOINTS = {
  // Пользователи
  USERS: '/users',
  USER_BY_ID: (id) => `/users?id=eq.${id}`,
  
  // Задачи
  TASKS: '/tasks',
  TASK_BY_ID: (id) => `/tasks?id=eq.${id}`,
  TASKS_BY_ASSIGNEE: (assigneeId) => `/tasks?assignee_id=eq.${assigneeId}`,
  
  // Проекты
  PROJECTS: '/projects',
  
  // Монтажи
  INSTALLATIONS: '/installations',
  
  // Задачи АВР
  TASKS_AVR: '/tasks_avr',
  
  // Чаты
  CHATS: '/chats',
  MESSAGES: '/messages',
  
  // Материалы
  MATERIALS: '/materials',
  MATERIALS_REQUESTS: '/materials_requests',
  
  // Заявки на закупку
  PURCHASE_REQUESTS: '/purchase_requests'
};

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.APP_CONFIG = APP_CONFIG;
  window.SUPABASE_CONFIG = SUPABASE_CONFIG;
  window.FIREBASE_CONFIG = FIREBASE_CONFIG;
  window.VAPID_PUBLIC_KEY = VAPID_PUBLIC_KEY;
  window.MAPBOX_TOKEN = MAPBOX_TOKEN;
}
