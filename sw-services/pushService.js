
const pushService = {
  DEFAULT_ICON: '/icons/icon-192x192.png',
  DEFAULT_BADGE: '/icons/badge-72x72.png',

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

  async handlePush(event) {
    const data = this.parsePushData(event);
    
    const title = data.title || 'РћРћРћ РљРѕСЂРЅРµРѕ';
    const options = {
      body: data.body || 'РќРѕРІРѕРµ СѓРІРµРґРѕРјР»РµРЅРёРµ',
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

    if (data.priority === 'high' || data.priority === 'urgent') {
      options.vibrate = [200, 100, 200];
    }

    console.log('[PushService] Showing notification:', title);
    return self.registration.showNotification(title, options);
  },

  getActions(data) {
    const actions = [];
    
    switch (data.type) {
      case 'chat_message':
        actions.push(
          { action: 'open_chat', title: 'РћС‚РєСЂС‹С‚СЊ С‡Р°С‚' },
          { action: 'reply', title: 'РћС‚РІРµС‚РёС‚СЊ' }
        );
        break;
      case 'task_assigned':
      case 'task_updated':
        actions.push(
          { action: 'view_task', title: 'РџРѕСЃРјРѕС‚СЂРµС‚СЊ Р·Р°РґР°С‡Сѓ' },
          { action: 'mark_done', title: 'Р’С‹РїРѕР»РЅРµРЅРѕ' }
        );
        break;
      case 'installation_update':
        actions.push(
          { action: 'view_installation', title: 'РћС‚РєСЂС‹С‚СЊ РјРѕРЅС‚Р°Р¶' }
        );
        break;
      default:
        actions.push(
          { action: 'open', title: 'РћС‚РєСЂС‹С‚СЊ' },
          { action: 'close', title: 'Р—Р°РєСЂС‹С‚СЊ' }
        );
    }
    
    return actions;
  },

  async handleClick(event) {
    const notification = event.notification;
    const action = event.action;
    const data = notification.data || {};
    
    console.log('[PushService] Notification clicked:', action, data);
    
    notification.close();
    
    let targetUrl = data.url || '/';
    
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
        if (data.taskId) {
          await this.markTaskDone(data.taskId);
        }
        targetUrl = '/tasks.html';
        break;
      case 'close':
        return;
      case 'reply':
        targetUrl = data.chatId ? `/chat.html?id=${data.chatId}&reply=true` : '/chat.html';
        break;
      case 'open':
      default:
        break;
    }
    
    await this.openWindow(targetUrl);
  },

  async openWindow(url) {
    const clients = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    });
    
    for (const client of clients) {
      if (client.url.includes(self.location.origin) && 'focus' in client) {
        await client.focus();
        await client.navigate(url);
        return;
      }
    }
    
    if (self.clients.openWindow) {
      await self.clients.openWindow(url);
    }
  },

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

  async getSubscription() {
    return await self.registration.pushManager.getSubscription();
  },

  isPushSupported() {
    return 'PushManager' in self;
  }
};
