
import { APP_CONFIG, FIREBASE_CONFIG, VAPID_PUBLIC_KEY } from './config.js';
import { authService } from './auth.js';

export class NotificationService {
  constructor() {
    this.subscription = null;
    this.messaging = null;
    this.permissionGranted = false;
  }

  async initFirebaseMessaging() {
    try {
      if (!window.firebase) {
        console.warn('вљ пёЏ Firebase РЅРµ РёРЅРёС†РёР°Р»РёР·РёСЂРѕРІР°РЅ');
        return null;
      }

      const messaging = window.firebase.messaging();
      this.messaging = messaging;

      const permission = await this.requestPermission();
      
      if (!permission) {
        return null;
      }

      const token = await this.getToken();
      
      if (token) {
        await authService.userProfileService.updateFCMToken(token);
        
        this.onMessage();
      }

      return token;
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° РёРЅРёС†РёР°Р»РёР·Р°С†РёРё Firebase Messaging:', error);
      return null;
    }
  }

  async requestPermission() {
    try {
      if ('Notification' in window) {
        const permission = await Notification.requestPermission();
        this.permissionGranted = permission === 'granted';
        
        if (this.permissionGranted) {
          console.log('вњ… Р Р°Р·СЂРµС€РµРЅРёРµ РЅР° СѓРІРµРґРѕРјР»РµРЅРёСЏ РїРѕР»СѓС‡РµРЅРѕ');
          
          await this.registerServiceWorker();
          
          return true;
        } else {
          console.warn('вљ пёЏ РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ Р·Р°РїСЂРµС‚РёР» СѓРІРµРґРѕРјР»РµРЅРёСЏ');
          return false;
        }
      } else {
        console.warn('вљ пёЏ Browser does not support notifications');
        return false;
      }
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° Р·Р°РїСЂРѕСЃР° СЂР°Р·СЂРµС€РµРЅРёСЏ:', error);
      return false;
    }
  }

  async registerServiceWorker() {
    try {
      if ('serviceWorker' in navigator) {
        const registration = await navigator.serviceWorker.register('./service-worker.js', {
          scope: './'
        });

        console.log('вњ… Service Worker Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅ:', registration.scope);
        
        this.subscription = await registration.pushManager.getSubscription();
        
        if (!this.subscription) {
          await this.createSubscription(registration);
        }

        return registration;
      } else {
        console.warn('вљ пёЏ Service Workers РЅРµ РїРѕРґРґРµСЂР¶РёРІР°СЋС‚СЃСЏ');
        return null;
      }
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° СЂРµРіРёСЃС‚СЂР°С†РёРё Service Worker:', error);
      return null;
    }
  }

  async createSubscription(registration) {
    try {
      const vapidKey = this.urlBase64ToUint8Array(VAPID_PUBLIC_KEY);
      
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: vapidKey
      });

      this.subscription = subscription;

      await this.saveSubscription(subscription);

      console.log('вњ… Push РїРѕРґРїРёСЃРєР° СЃРѕР·РґР°РЅР°');
      return subscription;
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° СЃРѕР·РґР°РЅРёСЏ РїРѕРґРїРёСЃРєРё:', error);
      return null;
    }
  }

  async saveSubscription(subscription) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      }

      const supabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );

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

      const { data: existing } = await supabase
        .from('user_push_subs')
        .select('id')
        .eq('user_id', currentUser.id)
        .single();

      let result;

      if (existing) {
        result = await supabase
          .from('user_push_subs')
          .update({
            ...subscriptionData,
            updated_at: new Date().toISOString()
          })
          .eq('id', existing.id);
      } else {
        result = await supabase
          .from('user_push_subs')
          .insert([subscriptionData]);
      }

      if (result.error) throw result.error;
      
      console.log('вњ… РџРѕРґРїРёСЃРєР° СЃРѕС…СЂР°РЅРµРЅР° РІ Р‘Р”');
      return true;
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° СЃРѕС…СЂР°РЅРµРЅРёСЏ РїРѕРґРїРёСЃРєРё:', error);
      return false;
    }
  }

  onMessage() {
    if (!this.messaging) return;

    window.firebase.onMessage((payload) => {
      console.log('рџ“© Р’С…РѕРґСЏС‰РµРµ СЃРѕРѕР±С‰РµРЅРёРµ:', payload);

      const notification = payload.notification;
      
      if (notification) {
        this.showLocalNotification({
          title: notification.title,
          body: notification.body,
          data: notification.data || {},
          icon: '/icon-192.png'
        });
      }
    });
  }

  showLocalNotification({ title, body, data = {}, icon = '/icon-192.png' }) {
    if (!this.permissionGranted) {
      console.warn('вљ пёЏ РќРµС‚ СЂР°Р·СЂРµС€РµРЅРёСЏ РЅР° РїРѕРєР°Р· СѓРІРµРґРѕРјР»РµРЅРёР№');
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
          title: 'РћС‚РєСЂС‹С‚СЊ'
        }
      ]
    };

    new Notification(title, options);
  }

  async getToken() {
    try {
      if (!this.messaging) {
        throw new Error('Firebase Messaging РЅРµ РёРЅРёС†РёР°Р»РёР·РёСЂРѕРІР°РЅ');
      }

      const token = await window.firebase.messaging.getToken(this.messaging, {
        vapidKey: VAPID_PUBLIC_KEY
      });

      console.log('рџЋ« FCM Token РїРѕР»СѓС‡РµРЅ:', token.substring(0, 20) + '...');
      return token;
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ С‚РѕРєРµРЅР°:', error);
      return null;
    }
  }

  async unsubscribe() {
    try {
      if (this.subscription) {
        await this.subscription.unsubscribe();
        this.subscription = null;
        
        console.log('вњ… РћС‚РїРёСЃРєР° РѕС‚ Push РІС‹РїРѕР»РЅРµРЅР°');
      }

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
      console.error('вќЊ РћС€РёР±РєР° РѕС‚РїРёСЃРєРё:', error);
      return false;
    }
  }

  isSupported() {
    return 'PushManager' in window && 'serviceWorker' in navigator;
  }

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

export const notificationService = new NotificationService();

if (typeof window !== 'undefined') {
  window.notificationService = notificationService;
}
