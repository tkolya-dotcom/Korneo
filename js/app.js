/**
 * Главный файл инициализации приложения
 * Подключает все модули и инициализирует приложение
 */

// Импортируем все модули
import { initSupabase, getSupabase } from './api.js';
import { authService, userProfileService } from './auth.js';
import { taskService, taskAVRService } from './tasks.js';
import { projectService } from './projects.js';
import { installationService } from './installations.js';
import { chatService } from './chat.js';
import { notificationService } from './notifications.js';
import { DateUtils, TextUtils, StatusUtils, FileUtils, MapUtils, Utils } from './utils.js';
import { APP_CONFIG, SUPABASE_CONFIG, FIREBASE_CONFIG } from './config.js';

/**
 * Инициализация приложения
 */
async function initApp() {
  console.log('🚀 Инициализация приложения...');
  
  try {
    // 1. Инициализация Supabase
    console.log('📦 Инициализация Supabase...');
    const supabase = initSupabase();
    
    // 2. Проверка сессии
    console.log('🔐 Проверка сессии...');
    const session = await authService.checkSession();
    
    if (session.authenticated) {
      console.log('✅ Пользователь авторизован:', session.profile?.name);
      
      // Обновляем UI для авторизованного пользователя
      updateUIForLoggedInUser(session.profile);
    } else {
      console.log('⚠️ Пользователь не авторизован');
      showLoginPage();
    }
    
    // 3. Инициализация уведомлений (если разрешено)
    console.log('🔔 Инициализация уведомлений...');
    if (Notification.permission === 'granted') {
      await notificationService.initFirebaseMessaging();
    }
    
    // 4. Подписка на изменения аутентификации
    authService.onAuthStateChange(async (event, session) => {
      console.log('🔄 Событие аутентификации:', event);
      
      if (event === 'SIGNED_IN' && session) {
        updateUIForLoggedInUser(authService.userProfile);
      } else if (event === 'SIGNED_OUT') {
        updateUIForLoggedOutUser();
      }
    });
    
    console.log('✅ Приложение инициализировано');
    
    // Экспортируем в window для отладки
    window.app = {
      authService,
      taskService,
      projectService,
      installationService,
      chatService,
      notificationService,
      utils: {
        DateUtils,
        TextUtils,
        StatusUtils,
        FileUtils,
        MapUtils,
        Utils
      }
    };
    
  } catch (error) {
    console.error('❌ Ошибка инициализации приложения:', error);
  }
}

/**
 * Обновление UI для авторизованного пользователя
 */
function updateUIForLoggedInUser(profile) {
  // Скрываем login страницу
  const authScreen = document.querySelector('.auth-screen');
  if (authScreen) {
    authScreen.classList.add('hidden');
  }
  
  // Показываем основное приложение
  const appContainer = document.querySelector('.container');
  if (appContainer) {
    appContainer.classList.remove('hidden');
  }
  
  // Обновляем информацию о пользователе в header
  const headerUser = document.querySelector('.header-user');
  if (headerUser && profile) {
    headerUser.textContent = `${profile.name} (${profile.role})`;
  }
  
  // Загружаем данные
  loadDashboardData();
}

/**
 * Обновление UI для неавторизованного пользователя
 */
function updateUIForLoggedOutUser() {
  // Показываем login страницу
  const authScreen = document.querySelector('.auth-screen');
  if (authScreen) {
    authScreen.classList.remove('hidden');
  }
  
  // Скрываем основное приложение
  const appContainer = document.querySelector('.container');
  if (appContainer) {
    appContainer.classList.add('hidden');
  }
}

/**
 * Показ страницы входа
 */
function showLoginPage() {
  const authScreen = document.querySelector('.auth-screen');
  if (authScreen) {
    authScreen.classList.remove('hidden');
  }
}

/**
 * Загрузка данных Dashboard
 */
async function loadDashboardData() {
  try {
    console.log('📊 Загрузка данных Dashboard...');
    
    const currentUser = authService.getCurrentUser();
    if (!currentUser) return;
    
    // Загружаем статистику
    const [taskStats, installationStats] = await Promise.all([
      taskService.getTaskStats(),
      installationService.getInstallationStats()
    ]);
    
    console.log('📊 Статистика:', { taskStats, installationStats });
    
    // Обновляем UI Dashboard
    updateDashboardUI({ taskStats, installationStats });
    
  } catch (error) {
    console.error('❌ Ошибка загрузки Dashboard:', error);
  }
}

/**
 * Обновление UI Dashboard
 */
function updateDashboardUI(data) {
  const { taskStats, installationStats } = data;
  
  // Обновляем виджеты задач
  const taskWidgets = {
    total: document.querySelector('[data-widget="tasks-total"]'),
    new: document.querySelector('[data-widget="tasks-new"]'),
    inProgress: document.querySelector('[data-widget="tasks-in-progress"]'),
    completed: document.querySelector('[data-widget="tasks-completed"]')
  };
  
  if (taskWidgets.total) taskWidgets.total.textContent = taskStats?.total || 0;
  if (taskWidgets.new) taskWidgets.new.textContent = taskStats?.new || 0;
  if (taskWidgets.inProgress) taskWidgets.inProgress.textContent = taskStats?.inProgress || 0;
  if (taskWidgets.completed) taskWidgets.completed.textContent = taskStats?.completed || 0;
  
  // Обновляем виджеты монтажей
  const installationWidgets = {
    total: document.querySelector('[data-widget="installations-total"]'),
    new: document.querySelector('[data-widget="installations-new"]'),
    inProgress: document.querySelector('[data-widget="installations-in-progress"]'),
    completed: document.querySelector('[data-widget="installations-completed"]')
  };
  
  if (installationWidgets.total) installationWidgets.total.textContent = installationStats?.total || 0;
  if (installationWidgets.new) installationWidgets.new.textContent = installationStats?.new || 0;
  if (installationWidgets.inProgress) installationWidgets.inProgress.textContent = installationStats?.inProgress || 0;
  if (installationWidgets.completed) installationWidgets.completed.textContent = installationStats?.completed || 0;
}

/**
 * Обработчик выхода
 */
async function handleLogout() {
  try {
    const result = await authService.signOut();
    
    if (result.success) {
      console.log('✅ Выход выполнен');
      updateUIForLoggedOutUser();
    }
  } catch (error) {
    console.error('❌ Ошибка выхода:', error);
  }
}

// Навешиваем обработчик на кнопку выхода
document.addEventListener('DOMContentLoaded', () => {
  const logoutBtn = document.querySelector('.logout-btn');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', handleLogout);
  }
  
  // Инициализируем приложение
  initApp();
});

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.initApp = initApp;
  window.handleLogout = handleLogout;
}
