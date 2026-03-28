// sw-services/chatService.js - Background chat sync for Service Worker

const chatService = {
  // Message queue for offline messages
  messageQueue: [],
  
  // Chat state
  state: {
    unreadCount: 0,
    lastMessageId: null,
    activeChats: new Set(),
    isSyncing: false
  },

  // Supabase config
  SUPABASE_URL: 'https://jmxjbdnqnzkzxgsfywha.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpteGpiZG5xbnprenhnc2Z5d2hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNTQ0MzQsImV4cCI6MjA4NjczMDQzNH0.z6y6DGs9Z6kojQYeAdsgKA-m4pxuoeABdY4rAojPEE4',

  // Queue a message for sending
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
    
    // Register for background sync if supported
    if ('sync' in self.registration) {
      try {
        await self.registration.sync.register('sync-messages');
      } catch (e) {
        console.error('[ChatService] Failed to register sync:', e);
      }
    }
    
    // Try to send immediately if online
    if (navigator.onLine) {
      this.flushQueue();
    }
    
    return messageWithId.id;
  },

  // Flush message queue
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
            // Notify client about failed message
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

  // Send single message to Supabase
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

  // Handle incoming message (from push)
  async handleMessage(messageData) {
    console.log('[ChatService] Handling incoming message:', messageData);
    
    this.state.lastMessageId = messageData.id;
    
    // Update unread count
    if (!this.state.activeChats.has(messageData.chat_id)) {
      this.state.unreadCount++;
    }
    
    // Notify all clients
    this.notifyClient('new_message', messageData);
    
    await this.saveState();
  },

  // Handle messages from client
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

  // Update badge count
  async updateBadge() {
    if ('setAppBadge' in navigator) {
      try {
        await navigator.setAppBadge(this.state.unreadCount);
      } catch (e) {
        console.error('[ChatService] Failed to set badge:', e);
      }
    }
    
    // Notify clients about badge update
    this.notifyClient('badge_update', { count: this.state.unreadCount });
  },

  // Clear badge
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

  // Notify all clients
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

  // Get chat stats
  getStats() {
    return {
      unreadCount: this.state.unreadCount,
      queueLength: this.messageQueue.length,
      activeChats: Array.from(this.state.activeChats),
      lastMessageId: this.state.lastMessageId,
      isSyncing: this.state.isSyncing
    };
  },

  // Save queue to cache
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

  // Load queue from cache
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

  // Save state to cache
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

  // Load state from cache
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

  // Get current user ID
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

  // Initialize
  init() {
    this.loadQueue();
    this.loadState();
    console.log('[ChatService] Initialized');
  }
};

// Initialize on load
chatService.init();
