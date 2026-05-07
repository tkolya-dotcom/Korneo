
import { initSupabase, getSupabase } from './api.js';
import { authService, userProfileService } from './auth.js';
import { taskService, taskAVRService } from './tasks.js';
import { projectService } from './projects.js';
import { installationService } from './installations.js';
import { chatService } from './chat.js';
import { notificationService } from './notifications.js';
import { DateUtils, TextUtils, StatusUtils, FileUtils, MapUtils, Utils } from './utils.js';
import { APP_CONFIG, SUPABASE_CONFIG, FIREBASE_CONFIG } from './config.js';

async function initApp() {
  console.log('рџљЂ РРЅРёС†РёР°Р»РёР·Р°С†РёСЏ РїСЂРёР»РѕР¶РµРЅРёСЏ...');
  
  try {
    console.log('рџ“¦ РРЅРёС†РёР°Р»РёР·Р°С†РёСЏ Supabase...');
    const supabase = initSupabase();
    
    console.log('рџ”ђ РџСЂРѕРІРµСЂРєР° СЃРµСЃСЃРёРё...');
    const session = await authService.checkSession();
    
    if (session.authenticated) {
      console.log('вњ… РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ:', session.profile?.name);
      
      updateUIForLoggedInUser(session.profile);
    } else {
      console.log('вљ пёЏ РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      showLoginPage();
    }
    
    console.log('рџ”” РРЅРёС†РёР°Р»РёР·Р°С†РёСЏ СѓРІРµРґРѕРјР»РµРЅРёР№...');
    if (Notification.permission === 'granted') {
      await notificationService.initFirebaseMessaging();
    }
    
    authService.onAuthStateChange(async (event, session) => {
      console.log('рџ”„ РЎРѕР±С‹С‚РёРµ Р°СѓС‚РµРЅС‚РёС„РёРєР°С†РёРё:', event);
      
      if (event === 'SIGNED_IN' && session) {
        updateUIForLoggedInUser(authService.userProfile);
      } else if (event === 'SIGNED_OUT') {
        updateUIForLoggedOutUser();
      }
    });
    
    console.log('вњ… РџСЂРёР»РѕР¶РµРЅРёРµ РёРЅРёС†РёР°Р»РёР·РёСЂРѕРІР°РЅРѕ');
    
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
    console.error('вќЊ РћС€РёР±РєР° РёРЅРёС†РёР°Р»РёР·Р°С†РёРё РїСЂРёР»РѕР¶РµРЅРёСЏ:', error);
  }
}

function updateUIForLoggedInUser(profile) {
  const authScreen = document.querySelector('.auth-screen');
  if (authScreen) {
    authScreen.classList.add('hidden');
  }
  
  const appContainer = document.querySelector('.container');
  if (appContainer) {
    appContainer.classList.remove('hidden');
  }
  
  const headerUser = document.querySelector('.header-user');
  if (headerUser && profile) {
    headerUser.textContent = `${profile.name} (${profile.role})`;
  }
  
  loadDashboardData();
}

function updateUIForLoggedOutUser() {
  const authScreen = document.querySelector('.auth-screen');
  if (authScreen) {
    authScreen.classList.remove('hidden');
  }
  
  const appContainer = document.querySelector('.container');
  if (appContainer) {
    appContainer.classList.add('hidden');
  }
}

function showLoginPage() {
  const authScreen = document.querySelector('.auth-screen');
  if (authScreen) {
    authScreen.classList.remove('hidden');
  }
}

async function loadDashboardData() {
  try {
    console.log('рџ“Љ Р—Р°РіСЂСѓР·РєР° РґР°РЅРЅС‹С… Dashboard...');
    
    const currentUser = authService.getCurrentUser();
    if (!currentUser) return;
    
    const [taskStats, installationStats] = await Promise.all([
      taskService.getTaskStats(),
      installationService.getInstallationStats()
    ]);
    
    console.log('рџ“Љ РЎС‚Р°С‚РёСЃС‚РёРєР°:', { taskStats, installationStats });
    
    updateDashboardUI({ taskStats, installationStats });
    
  } catch (error) {
    console.error('вќЊ РћС€РёР±РєР° Р·Р°РіСЂСѓР·РєРё Dashboard:', error);
  }
}

function updateDashboardUI(data) {
  const { taskStats, installationStats } = data;
  
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

async function handleLogout() {
  try {
    const result = await authService.signOut();
    
    if (result.success) {
      console.log('вњ… Р’С‹С…РѕРґ РІС‹РїРѕР»РЅРµРЅ');
      updateUIForLoggedOutUser();
    }
  } catch (error) {
    console.error('вќЊ РћС€РёР±РєР° РІС‹С…РѕРґР°:', error);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const logoutBtn = document.querySelector('.logout-btn');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', handleLogout);
  }
  
  initApp();
});

if (typeof window !== 'undefined') {
  window.initApp = initApp;
  window.handleLogout = handleLogout;
}
