/**
 * Система уведомлений (Push + FCM)
 */

import { APP_CONFIG, FIREBASE_CONFIG, VAPID_PUBLIC_KEY } from './config.js';
import { authService } from './auth.js';

/**
 * Сервис Push-уведомлений
 */
export class NotificationService {
  constructor() {
    this.subscription = null;
    this.messaging = null;
    this.permissionGranted = false;
  }

  /**
   * Инициализация Firebase Messaging
   */
  async initFirebaseMessaging() {
    try {
      // Проверяем, загружен ли Firebase
      if (!window.firebase) {
        console.warn('⚠️ Firebase не инициализирован');
        return null;
      }

      const messaging = window.firebase.messaging();
      this.messaging = messaging;

      // Запрашиваем разрешение
      const permission = await this.requestPermission();
      
      if (!permission) {
        return null;
      }

      // Получаем токен
      const token = await this.getToken();
      
      if (token) {
        // Сохраняем токен в профиль пользователя
        await authService.userProfileService.updateFCMToken(token);
        
        // Слушаем входящие сообщения
        this.onMessage();
      }

      return token;
    } catch (error) {
      console.error('❌ Ошибка инициализации Firebase Messaging:', error);
      return null;
    }
  }

  /**
   * Запрос разрешения на уведомления
   */
  async requestPermission() {
    try {
      if ('Notification' in window) {
        const permission = await Notification.requestPermission();
        this.permissionGranted = permission === 'granted';
        
        if (this.permissionGranted) {
          console.log('✅ Разрешение на уведомления получено');
          
          // Регистрируем Service Worker
          await this.registerServiceWorker();
          
          return true;
        } else {
          console.warn('⚠️ Пользователь запретил уведомления');
          return false;
        }
      } else {
        console.warn('⚠️ Browser does not support notifications');
        return false;
      }
    } catch (error) {
      console.error('❌ Ошибка запроса разрешения:', error);
      return false;
    }
  }

  /**
   * Регистрация Service Worker
   */
  async registerServiceWorker() {
    try {
      if ('serviceWorker' in navigator) {
        const registration = await navigator.serviceWorker.register('./service-worker.js', {
          scope: './'
        });

        console.log('✅ Service Worker зарегистрирован:', registration.scope);
        
        // Проверяем наличие активной подписки
        this.subscription = await registration.pushManager.getSubscription();
        
        if (!this.subscription) {
          // Создаём новую подписку
          await this.createSubscription(registration);
        }

        return registration;
      } else {
        console.warn('⚠️ Service Workers не поддерживаются');
        return null;
      }
    } catch (error) {
      console.error('❌ Ошибка регистрации Service Worker:', error);
      return null;
    }
  }

  /**
   * Создание подписки на Push
   */
  async createSubscription(registration) {
    try {
      // Конвертируем VAPID ключ
      const vapidKey = this.urlBase64ToUint8Array(VAPID_PUBLIC_KEY);
      
      // Создаём подписку
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: vapidKey
      });

      this.subscription = subscription;

      // Отправляем подписку на сервер
      await this.saveSubscription(subscription);

      console.log('✅ Push подписка создана');
      return subscription;
    } catch (error) {
      console.error('❌ Ошибка создания подписки:', error);
      return null;
    }
  }

  /**
   * Сохранение подписки в БД
   */
  async saveSubscription(subscription) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('Пользователь не авторизован');
      }

      const supabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );

      // Преобразуем подписку в формат для БД
      const subscriptionData = {
        user_id: currentUser.id,
        endpoint: subscription.endpoint,
        p256dh: this.arrayBufferToBase64(
          new Uint8Array(subscription.getKey('p256dh'))
        ),
        auth: this.arrayBufferToBase64(
          new Uint8Array(subscription.getKey('auth'))
        )
      };

      // Проверяем существующую подписку
      const { data: existing } = await supabase
        .from('user_push_subs')
        .select('id')
        .eq('user_id', currentUser.id)
        .single();

      let result;

      if (existing) {
        // Обновляем
        result = await supabase
          .from('user_push_subs')
          .update({
            ...subscriptionData,
            updated_at: new Date().toISOString()
          })
          .eq('id', existing.id);
      } else {
        // Создаём новую
        result = await supabase
          .from('user_push_subs')
          .insert([subscriptionData]);
      }

      if (result.error) throw result.error;
      
      console.log('✅ Подписка сохранена в БД');
      return true;
    } catch (error) {
      console.error('❌ Ошибка сохранения подписки:', error);
      return false;
    }
  }

  /**
   * Обработка входящих сообщений (когда приложение активно)
   */
  onMessage() {
    if (!this.messaging) return;

    window.firebase.onMessage((payload) => {
      console.log('📩 Входящее сообщение:', payload);

      const notification = payload.notification;
      
      if (notification) {
        // Показываем уведомление
        this.showLocalNotification({
          title: notification.title,
          body: notification.body,
          data: notification.data || {},
          icon: '/icon-192.png'
        });
      }
    });
  }

  /**
   * Показ локального уведомления
   */
  showLocalNotification({ title, body, data = {}, icon = '/icon-192.png' }) {
    if (!this.permissionGranted) {
      console.warn('⚠️ Нет разрешения на показ уведомлений');
      return;
    }

    const options = {
      body,
      icon,
      badge: '/icon-192.png',
      vibrate: [200, 100, 200],
      data: {
        url: data.url || window.location.origin,
        ...data
      },
      actions: [
        {
          action: 'open',
          title: 'Открыть'
        }
      ]
    };

    new Notification(title, options);
  }

  /**
   * Получение токена FCM
   */
  async getToken() {
    try {
      if (!this.messaging) {
        throw new Error('Firebase Messaging не инициализирован');
      }

      const token = await window.firebase.messaging.getToken(this.messaging, {
        vapidKey: VAPID_PUBLIC_KEY
      });

      console.log('🎫 FCM Token получен:', token.substring(0, 20) + '...');
      return token;
    } catch (error) {
      console.error('❌ Ошибка получения токена:', error);
      return null;
    }
  }

  /**
   * Отписка от Push-уведомлений
   */
  async unsubscribe() {
    try {
      if (this.subscription) {
        await this.subscription.unsubscribe();
        this.subscription = null;
        
        console.log('✅ Отписка от Push выполнена');
      }

      // Удаляем подписку из БД
      const currentUser = authService.getCurrentUser();
      
      if (currentUser) {
        const supabase = window.supabase.createClient(
          window.SUPABASE_CONFIG.url,
          window.SUPABASE_CONFIG.anonKey
        );

        await supabase
          .from('user_push_subs')
          .delete()
          .eq('user_id', currentUser.id);
      }

      return true;
    } catch (error) {
      console.error('❌ Ошибка отписки:', error);
      return false;
    }
  }

  /**
   * Проверка поддержки Push API
   */
  isSupported() {
    return 'PushManager' in window && 'serviceWorker' in navigator;
  }

  /**
   * Утилита: Base64 → Uint8Array
   */
  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding)
      .replace(/\-/g, '+')
      .replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    
    return outputArray;
  }

  /**
   * Утилита: ArrayBuffer → Base64
   */
  arrayBufferToBase64(buffer) {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    const len = bytes.byteLength;
    
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    
    return window.btoa(binary);
  }
}

// Экспорт экземпляра
export const notificationService = new NotificationService();

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.notificationService = notificationService;
}
