// sw-services/pushService.js - Push notification handling for Service Worker

const pushService = {
  // Default notification icon
  DEFAULT_ICON: '/icons/icon-192x192.png',
  DEFAULT_BADGE: '/icons/badge-72x72.png',

  // Parse push data safely
  parsePushData(event) {
    try {
      if (event.data) {
        return event.data.json();
      }
    } catch (e) {
      console.error('[PushService] Failed to parse push data:', e);
    }
    return {};
  },

  // Handle incoming push event
  async handlePush(event) {
    const data = this.parsePushData(event);
    
    const title = data.title || 'ООО Корнео';
    const options = {
      body: data.body || 'Новое уведомление',
      icon: data.icon || this.DEFAULT_ICON,
      badge: data.badge || this.DEFAULT_BADGE,
      tag: data.tag || 'default',
      requireInteraction: data.requireInteraction || false,
      renotify: data.renotify || false,
      silent: data.silent || false,
      data: {
        url: data.url || '/',
        chatId: data.chat_id || null,
        messageId: data.message_id || null,
        taskId: data.task_id || null,
        type: data.type || 'general',
        ...data
      },
      actions: this.getActions(data)
    };

    // Add vibration pattern for important notifications
    if (data.priority === 'high' || data.priority === 'urgent') {
      options.vibrate = [200, 100, 200];
    }

    console.log('[PushService] Showing notification:', title);
    return self.registration.showNotification(title, options);
  },

  // Get notification actions based on type
  getActions(data) {
    const actions = [];
    
    switch (data.type) {
      case 'chat_message':
        actions.push(
          { action: 'open_chat', title: 'Открыть чат' },
          { action: 'reply', title: 'Ответить' }
        );
        break;
      case 'task_assigned':
      case 'task_updated':
        actions.push(
          { action: 'view_task', title: 'Посмотреть задачу' },
          { action: 'mark_done', title: 'Выполнено' }
        );
        break;
      case 'installation_update':
        actions.push(
          { action: 'view_installation', title: 'Открыть монтаж' }
        );
        break;
      default:
        actions.push(
          { action: 'open', title: 'Открыть' },
          { action: 'close', title: 'Закрыть' }
        );
    }
    
    return actions;
  },

  // Handle notification click
  async handleClick(event) {
    const notification = event.notification;
    const action = event.action;
    const data = notification.data || {};
    
    console.log('[PushService] Notification clicked:', action, data);
    
    // Close notification
    notification.close();
    
    // Determine target URL
    let targetUrl = data.url || '/';
    
    // Handle specific actions
    switch (action) {
      case 'open_chat':
        targetUrl = data.chatId ? `/chat.html?id=${data.chatId}` : '/chat.html';
        break;
      case 'view_task':
        targetUrl = data.taskId ? `/tasks.html?id=${data.taskId}` : '/tasks.html';
        break;
      case 'view_installation':
        targetUrl = data.installationId ? `/installations.html?id=${data.installationId}` : '/installations.html';
        break;
      case 'mark_done':
        // Mark task as done via API
        if (data.taskId) {
          await this.markTaskDone(data.taskId);
        }
        targetUrl = '/tasks.html';
        break;
      case 'close':
        // Just close, don't open window
        return;
      case 'reply':
        // Open chat with reply focus
        targetUrl = data.chatId ? `/chat.html?id=${data.chatId}&reply=true` : '/chat.html';
        break;
      case 'open':
      default:
        // Use default URL from data
        break;
    }
    
    // Open or focus window
    await this.openWindow(targetUrl);
  },

  // Open or focus existing window
  async openWindow(url) {
    const clients = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    });
    
    // Look for existing window with same origin
    for (const client of clients) {
      if (client.url.includes(self.location.origin) && 'focus' in client) {
        await client.focus();
        // Navigate to target URL
        await client.navigate(url);
        return;
      }
    }
    
    // Open new window if none exists
    if (self.clients.openWindow) {
      await self.clients.openWindow(url);
    }
  },

  // Mark task as done (background API call)
  async markTaskDone(taskId) {
    try {
      const SUPABASE_URL = 'https://jmxjbdnqnzkzxgsfywha.supabase.co';
      const response = await fetch(`${SUPABASE_URL}/rest/v1/tasks?id=eq.${taskId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Prefer': 'return=minimal'
        },
        body: JSON.stringify({ status: 'completed', updated_at: new Date().toISOString() })
      });
      
      if (response.ok) {
        console.log('[PushService] Task marked as done:', taskId);
      }
    } catch (error) {
      console.error('[PushService] Failed to mark task done:', error);
    }
  },

  // Get subscription info
  async getSubscription() {
    return await self.registration.pushManager.getSubscription();
  },

  // Check if push is supported
  isPushSupported() {
    return 'PushManager' in self;
  }
};
