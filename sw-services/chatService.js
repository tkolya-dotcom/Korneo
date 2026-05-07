
const chatService = {
  messageQueue: [],
  
  state: {
    unreadCount: 0,
    lastMessageId: null,
    activeChats: new Set(),
    isSyncing: false
  },

  SUPABASE_URL: 'https://jmxjbdnqnzkzxgsfywha.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpteGpiZG5xbnprenhnc2Z5d2hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNTQ0MzQsImV4cCI6MjA4NjczMDQzNH0.z6y6DGs9Z6kojQYeAdsgKA-m4pxuoeABdY4rAojPEE4',

  async queueMessage(message) {
    const messageWithId = {
      ...message,
      id: message.id || `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      queuedAt: new Date().toISOString(),
      retryCount: 0
    };
    
    this.messageQueue.push(messageWithId);
    await this.saveQueue();
    
    console.log('[ChatService] Message queued:', messageWithId.id);
    
    if ('sync' in self.registration) {
      try {
        await self.registration.sync.register('sync-messages');
      } catch (e) {
        console.error('[ChatService] Failed to register sync:', e);
      }
    }
    
    if (navigator.onLine) {
      this.flushQueue();
    }
    
    return messageWithId.id;
  },

  async flushQueue() {
    if (this.state.isSyncing || this.messageQueue.length === 0) {
      return;
    }
    
    this.state.isSyncing = true;
    
    const messagesToSend = [...this.messageQueue];
    const failedMessages = [];
    
    for (const message of messagesToSend) {
      try {
        const success = await this.sendMessage(message);
        if (!success) {
          message.retryCount++;
          if (message.retryCount < 3) {
            failedMessages.push(message);
          } else {
            console.error('[ChatService] Message failed after 3 retries:', message.id);
            this.notifyClient('message_failed', { messageId: message.id });
          }
        }
      } catch (error) {
        console.error('[ChatService] Error sending message:', error);
        message.retryCount++;
        if (message.retryCount < 3) {
          failedMessages.push(message);
        }
      }
    }
    
    this.messageQueue = failedMessages;
    await this.saveQueue();
    
    this.state.isSyncing = false;
    
    console.log('[ChatService] Queue flushed. Remaining:', this.messageQueue.length);
  },

  async sendMessage(message) {
    try {
      const userId = await this.getCurrentUserId();
      if (!userId) {
        console.error('[ChatService] No user ID available');
        return false;
      }

      const response = await fetch(`${this.SUPABASE_URL}/rest/v1/messages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': this.SUPABASE_ANON_KEY,
          'Authorization': `Bearer ${this.SUPABASE_ANON_KEY}`,
          'Prefer': 'return=minimal'
        },
        body: JSON.stringify({
          chat_id: message.chat_id,
          sender_id: userId,
          content: message.content,
          message_type: message.message_type || 'text',
          file_url: message.file_url || null,
          reply_to: message.reply_to || null,
          created_at: new Date().toISOString()
        })
      });

      if (response.ok) {
        console.log('[ChatService] Message sent:', message.id);
        this.notifyClient('message_sent', { messageId: message.id });
        return true;
      } else {
        console.error('[ChatService] Failed to send message:', response.status);
        return false;
      }
    } catch (error) {
      console.error('[ChatService] Network error sending message:', error);
      return false;
    }
  },

  async handleMessage(messageData) {
    console.log('[ChatService] Handling incoming message:', messageData);
    
    this.state.lastMessageId = messageData.id;
    
    if (!this.state.activeChats.has(messageData.chat_id)) {
      this.state.unreadCount++;
    }
    
    this.notifyClient('new_message', messageData);
    
    await this.saveState();
  },

  async handleClientMessage(event) {
    const data = event.data;
    
    if (!data || !data.type) return;
    
    switch (data.type) {
      case 'SEND_MESSAGE':
        await this.queueMessage(data.message);
        break;
        
      case 'JOIN_CHAT':
        this.state.activeChats.add(data.chatId);
        break;
        
      case 'LEAVE_CHAT':
        this.state.activeChats.delete(data.chatId);
        break;
        
      case 'MARK_READ':
        this.state.unreadCount = Math.max(0, this.state.unreadCount - (data.count || 1));
        await this.saveState();
        break;
        
      case 'GET_UNREAD_COUNT':
        event.source.postMessage({
          type: 'UNREAD_COUNT',
          count: this.state.unreadCount
        });
        break;
    }
  },

  async updateBadge() {
    if ('setAppBadge' in navigator) {
      try {
        await navigator.setAppBadge(this.state.unreadCount);
      } catch (e) {
        console.error('[ChatService] Failed to set badge:', e);
      }
    }
    
    this.notifyClient('badge_update', { count: this.state.unreadCount });
  },

  async clearBadge() {
    this.state.unreadCount = 0;
    await this.saveState();
    
    if ('clearAppBadge' in navigator) {
      try {
        await navigator.clearAppBadge();
      } catch (e) {
        console.error('[ChatService] Failed to clear badge:', e);
      }
    }
    
    this.notifyClient('badge_update', { count: 0 });
  },

  notifyClient(type, data) {
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
      clients.forEach(client => {
        client.postMessage({
          type,
          data,
          timestamp: new Date().toISOString()
        });
      });
    });
  },

  getStats() {
    return {
      unreadCount: this.state.unreadCount,
      queueLength: this.messageQueue.length,
      activeChats: Array.from(this.state.activeChats),
      lastMessageId: this.state.lastMessageId,
      isSyncing: this.state.isSyncing
    };
  },

  async saveQueue() {
    try {
      const cache = await caches.open('chat-cache');
      await cache.put(
        'message-queue',
        new Response(JSON.stringify(this.messageQueue))
      );
    } catch (e) {
      console.error('[ChatService] Failed to save queue:', e);
    }
  },

  async loadQueue() {
    try {
      const cache = await caches.open('chat-cache');
      const response = await cache.match('message-queue');
      if (response) {
        this.messageQueue = await response.json();
        console.log('[ChatService] Loaded queue:', this.messageQueue.length, 'messages');
      }
    } catch (e) {
      console.error('[ChatService] Failed to load queue:', e);
    }
  },

  async saveState() {
    try {
      const cache = await caches.open('chat-cache');
      await cache.put(
        'chat-state',
        new Response(JSON.stringify({
          unreadCount: this.state.unreadCount,
          lastMessageId: this.state.lastMessageId,
          activeChats: Array.from(this.state.activeChats)
        }))
      );
    } catch (e) {
      console.error('[ChatService] Failed to save state:', e);
    }
  },

  async loadState() {
    try {
      const cache = await caches.open('chat-cache');
      const response = await cache.match('chat-state');
      if (response) {
        const data = await response.json();
        this.state.unreadCount = data.unreadCount || 0;
        this.state.lastMessageId = data.lastMessageId || null;
        this.state.activeChats = new Set(data.activeChats || []);
      }
    } catch (e) {
      console.error('[ChatService] Failed to load state:', e);
    }
  },

  async getCurrentUserId() {
    try {
      const cache = await caches.open('auth-cache');
      const response = await cache.match('current-user');
      if (response) {
        const user = await response.json();
        return user.id;
      }
    } catch (e) {
      console.error('[ChatService] Failed to get user ID:', e);
    }
    return null;
  },

  init() {
    this.loadQueue();
    this.loadState();
    console.log('[ChatService] Initialized');
  }
};

chatService.init();
