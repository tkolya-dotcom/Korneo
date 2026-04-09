/**
 * Аутентификация и управление пользователями
 */

import { getSupabase, repositories } from './api.js';
import { APP_CONFIG } from './config.js';

const { roles } = APP_CONFIG;

/**
 * Класс для работы с аутентификацией
 */
export class AuthService {
  constructor() {
    this.supabase = getSupabase();
    this.currentUser = null;
    this.userProfile = null;
  }

  /**
   * Вход по email/паролю
   */
  async signIn(email, password) {
    try {
      const { data, error } = await this.supabase.auth.signInWithPassword({
        email,
        password,
        options: {
          redirectTo: window.location.origin
        }
      });

      if (error) throw error;

      this.currentUser = data.user;
      this.userProfile = await repositories.users.getCurrentUser();
      
      // Сохраняем в localStorage
      localStorage.setItem('user_id', data.user.id);
      localStorage.setItem('user_role', this.userProfile?.role || 'worker');
      
      console.log('✅ Вход выполнен:', email);
      return { success: true, user: data.user, profile: this.userProfile };
    } catch (error) {
      console.error('❌ Ошибка входа:', error.message);
      return { 
        success: false, 
        error: this._mapAuthError(error) 
      };
    }
  }

  /**
   * Регистрация нового пользователя
   */
  async signUp(email, password, name, role = 'worker') {
    try {
      // Проверка на запрещённые роли
      if (['manager', 'deputy_head', 'admin'].includes(role)) {
        return {
          success: false,
          error: 'Регистрация на эту роль невозможна'
        };
      }

      const { data, error } = await this.supabase.auth.signUp({
        email,
        password,
        options: {
          redirectTo: window.location.origin,
          data: {
            name,
            role
          }
        }
      });

      if (error) throw error;

      console.log('✅ Регистрация выполнена:', email);
      return { success: true, user: data.user };
    } catch (error) {
      console.error('❌ Ошибка регистрации:', error.message);
      return { 
        success: false, 
        error: this._mapAuthError(error) 
      };
    }
  }

  /**
   * Выход из системы
   */
  async signOut() {
    try {
      // Помечаем пользователя как offline
      if (this.currentUser?.id) {
        await repositories.users.setOffline(this.currentUser.id);
      }

      await this.supabase.auth.signOut();
      
      // Очищаем localStorage
      localStorage.removeItem('user_id');
      localStorage.removeItem('user_role');
      localStorage.removeItem('current_task_filter');
      
      this.currentUser = null;
      this.userProfile = null;
      
      console.log('✅ Выход выполнен');
      return { success: true };
    } catch (error) {
      console.error('❌ Ошибка выхода:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Проверка текущей сессии
   */
  async checkSession() {
    try {
      const { data: { session } } = await this.supabase.auth.getSession();
      
      if (!session) {
        return { authenticated: false };
      }

      this.currentUser = session.user;
      this.userProfile = await repositories.users.getCurrentUser();
      
      // Обновляем last_seen
      if (this.userProfile) {
        await repositories.users.updateLastSeen(this.currentUser.id);
      }

      // Сохраняем в localStorage
      localStorage.setItem('user_id', this.currentUser.id);
      localStorage.setItem('user_role', this.userProfile?.role || 'worker');

      return {
        authenticated: true,
        user: this.currentUser,
        profile: this.userProfile
      };
    } catch (error) {
      console.error('❌ Ошибка проверки сессии:', error.message);
      return { authenticated: false, error: error.message };
    }
  }

  /**
   * Получение текущего пользователя
   */
  getCurrentUser() {
    return this.currentUser;
  }

  /**
   * Получение профиля пользователя
   */
  getUserProfile() {
    return this.userProfile;
  }

  /**
   * Проверка роли
   */
  hasRole(requiredRoles) {
    if (!this.userProfile) return false;
    
    const userRole = this.userProfile.role;
    
    if (Array.isArray(requiredRoles)) {
      return requiredRoles.includes(userRole);
    }
    
    return userRole === requiredRoles;
  }

  /**
   * Проверка прав на создание задач
   */
  canCreateTasks() {
    return this.hasRole([roles.ENGINEER, roles.MANAGER, roles.DEPUTY_HEAD, roles.ADMIN]);
  }

  /**
   * Проверка прав на удаление задач
   */
  canDeleteTasks() {
    return this.hasRole([roles.MANAGER, roles.DEPUTY_HEAD, roles.ADMIN]);
  }

  /**
   * Проверка прав на управление пользователями
   */
  canManageUsers() {
    return this.hasRole([roles.MANAGER, roles.DEPUTY_HEAD, roles.ADMIN]);
  }

  /**
   * Проверка прав на одобрение заявок
   */
  canApproveRequests() {
    return this.hasRole([roles.MANAGER, roles.DEPUTY_HEAD, roles.ADMIN]);
  }

  /**
   * Смена пароля
   */
  async updatePassword(newPassword) {
    try {
      const { error } = await this.supabase.auth.updateUser({
        password: newPassword
      });

      if (error) throw error;

      console.log('✅ Пароль изменён');
      return { success: true };
    } catch (error) {
      console.error('❌ Ошибка смены пароля:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Восстановление пароля
   */
  async resetPassword(email) {
    try {
      const { error } = await this.supabase.auth.resetPasswordForEmail(email, {
        redirectTo: window.location.origin + '/reset-password'
      });

      if (error) throw error;

      console.log('✅ Письмо для сброса отправлено');
      return { success: true };
    } catch (error) {
      console.error('❌ Ошибка восстановления пароля:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Подписка на изменения аутентификации
   */
  onAuthStateChange(callback) {
    return this.supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session) {
        this.currentUser = session.user;
        this.userProfile = await repositories.users.getCurrentUser();
      } else if (event === 'SIGNED_OUT') {
        this.currentUser = null;
        this.userProfile = null;
      }
      
      callback(event, session);
    });
  }

  /**
   * Маппинг ошибок аутентификации
   */
  _mapAuthError(error) {
    const errorMessages = {
      'Invalid login credentials': 'Неверный email или пароль',
      'Email not confirmed': 'Email не подтверждён',
      'User already registered': 'Пользователь уже существует',
      'Weak password': 'Слишком слабый пароль (мин. 6 символов)',
      'Over request rate limit': 'Слишком много запросов, попробуйте позже'
    };

    return errorMessages[error.message] || error.message;
  }
}

/**
 * Управление профилем пользователя
 */
export class UserProfileService {
  constructor() {
    this.authService = new AuthService();
  }

  /**
   * Обновление профиля
   */
  async updateProfile(updates) {
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser) {
        throw new Error('Пользователь не авторизован');
      }

      const updated = await repositories.users.update(currentUser.id, updates);
      
      this.authService.userProfile = updated;
      
      console.log('✅ Профиль обновлён');
      return { success: true, profile: updated };
    } catch (error) {
      console.error('❌ Ошибка обновления профиля:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Загрузка аватара
   */
  async uploadAvatar(file) {
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser) {
        throw new Error('Пользователь не авторизован');
      }

      // Создаём имя файла
      const fileExt = file.name.split('.').pop();
      const fileName = `${currentUser.id}.${fileExt}`;
      
      // Загружаем в Storage
      const { data, error } = await this.authService.supabase.storage
        .from('avatars')
        .upload(fileName, file, { upsert: true });

      if (error) throw error;

      // Получаем публичный URL
      const { data: { publicUrl } } = this.authService.supabase.storage
        .from('avatars')
        .getPublicUrl(fileName);

      // Обновляем профиль
      return await this.updateProfile({ avatar_url: publicUrl });
    } catch (error) {
      console.error('❌ Ошибка загрузки аватара:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Обновление FCM токена
   */
  async updateFCMToken(token) {
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser) {
        throw new Error('Пользователь не авторизован');
      }

      return await repositories.users.update(currentUser.id, {
        fcm_token: token
      });
    } catch (error) {
      console.error('❌ Ошибка обновления FCM токена:', error.message);
      return null;
    }
  }
}

// Экспорт экземпляров
export const authService = new AuthService();
export const userProfileService = new UserProfileService();

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.authService = authService;
  window.userProfileService = userProfileService;
}
