// sw-services/trackingService.js - Background tracking and analytics for Service Worker

const trackingService = {
  // State management
  state: {
    notificationsReceived: 0,
    notificationsClicked: 0,
    messagesSent: 0,
    messagesReceived: 0,
    lastSync: null,
    lastLocation: null,
    syncCount: 0,
    swActivations: 0,
    errors: []
  },

  // Queue for offline events
  eventQueue: [],

  // Supabase config
  SUPABASE_URL: 'https://jmxjbdnqnzkzxgsfywha.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpteGpiZG5xbnprenhnc2Z5d2hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzExNTQ0MzQsImV4cCI6MjA4NjczMDQzNH0.z6y6DGs9Z6kojQYeAdsgKA-m4pxuoeABdY4rAojPEE4',

  // Initialize service
  init() {
    console.log('[TrackingService] Initialized');
    this.loadState();
    this.startPeriodicSync();
  },

  // Load state from storage
  async loadState() {
    try {
      const stored = await self.caches.match('tracking-state');
      if (stored) {
        const data = await stored.json();
        this.state = { ...this.state, ...data };
      }
    } catch (e) {
      console.error('[TrackingService] Failed to load state:', e);
    }
  },

  // Save state to storage
  async saveState() {
    try {
      const cache = await caches.open('tracking-cache');
      await cache.put(
        'tracking-state',
        new Response(JSON.stringify(this.state))
      );
    } catch (e) {
      console.error('[TrackingService] Failed to save state:', e);
    }
  },

  // Track an event
  track(eventName, data = {}) {
    const event = {
      type: eventName,
      timestamp: new Date().toISOString(),
      data: data,
      sessionId: this.getSessionId()
    };

    console.log('[TrackingService] Event:', eventName, data);

    // Add to queue
    this.eventQueue.push(event);

    // Update local state
    switch (eventName) {
      case 'notification_click':
        this.state.notificationsClicked++;
        break;
      case 'notification_close':
        break;
      case 'sw_activate':
        this.state.swActivations++;
        break;
      case 'message_sent':
        this.state.messagesSent++;
        break;
      case 'message_received':
        this.state.messagesReceived++;
        break;
      case 'background_sync':
        this.state.syncCount++;
        break;
    }

    // Persist state
    this.saveState();

    // Try to flush immediately if online
    if (navigator.onLine && this.eventQueue.length >= 10) {
      this.flushQueue();
    }
  },

  // Update state directly
  updateState(updates) {
    this.state = { ...this.state, ...updates };
    this.saveState();
  },

  // Get current state
  getState() {
    return {
      ...this.state,
      queueLength: this.eventQueue.length,
      isOnline: navigator.onLine
    };
  },

  // Flush event queue to Supabase
  async flushQueue() {
    if (this.eventQueue.length === 0) return;

    const eventsToSend = [...this.eventQueue];
    this.eventQueue = [];

    try {
      // Send to analytics endpoint
      const response = await fetch(`${this.SUPABASE_URL}/rest/v1/analytics_events`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': this.SUPABASE_ANON_KEY,
          'Authorization': `Bearer ${this.SUPABASE_ANON_KEY}`,
          'Prefer': 'return=minimal'
        },
        body: JSON.stringify(eventsToSend.map(e => ({
          event_type: e.type,
          event_data: e.data,
          created_at: e.timestamp,
          session_id: e.sessionId
        })))
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      this.state.lastSync = new Date().toISOString();
      await this.saveState();
      console.log('[TrackingService] Flushed', eventsToSend.length, 'events');
    } catch (error) {
      console.error('[TrackingService] Failed to flush queue:', error);
      // Put events back in queue
      this.eventQueue.unshift(...eventsToSend);
      
      // Keep only last 100 events
      if (this.eventQueue.length > 100) {
        this.eventQueue = this.eventQueue.slice(-100);
      }
    }
  },

  // Sync state with server
  async syncState() {
    await this.flushQueue();
    
    // Update last location if available
    if (this.state.lastLocation) {
      await this.sendLocationUpdate(this.state.lastLocation);
    }
  },

  // Background geolocation tracking
  async trackLocation(position) {
    const location = {
      latitude: position.coords.latitude,
      longitude: position.coords.longitude,
      accuracy: position.coords.accuracy,
      timestamp: new Date().toISOString()
    };

    this.state.lastLocation = location;
    await this.saveState();

    // Send to server
    await this.sendLocationUpdate(location);
  },

  // Send location update to Supabase
  async sendLocationUpdate(location) {
    try {
      const userId = await this.getCurrentUserId();
      if (!userId) return;

      const response = await fetch(`${this.SUPABASE_URL}/rest/v1/user_locations`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'apikey': this.SUPABASE_ANON_KEY,
          'Authorization': `Bearer ${this.SUPABASE_ANON_KEY}`,
          'Prefer': 'return=minimal'
        },
        body: JSON.stringify({
          user_id: userId,
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy,
          recorded_at: location.timestamp
        })
      });

      if (response.ok) {
        console.log('[TrackingService] Location updated');
      }
    } catch (error) {
      console.error('[TrackingService] Failed to send location:', error);
    }
  },

  // Get current user ID from storage
  async getCurrentUserId() {
    try {
      const cache = await caches.open('auth-cache');
      const response = await cache.match('current-user');
      if (response) {
        const user = await response.json();
        return user.id;
      }
    } catch (e) {
      console.error('[TrackingService] Failed to get user ID:', e);
    }
    return null;
  },

  // Generate session ID
  getSessionId() {
    let sessionId = self.sessionStorage?.getItem?.('sw-session-id');
    if (!sessionId) {
      sessionId = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      try {
        self.sessionStorage?.setItem?.('sw-session-id', sessionId);
      } catch (e) {}
    }
    return sessionId;
  },

  // Start periodic sync
  startPeriodicSync() {
    // Sync every 5 minutes
    setInterval(() => {
      this.flushQueue();
    }, 5 * 60 * 1000);
  },

  // Log error
  logError(error, context = {}) {
    const errorEntry = {
      message: error.message || String(error),
      stack: error.stack,
      timestamp: new Date().toISOString(),
      context
    };
    
    this.state.errors.push(errorEntry);
    
    // Keep only last 50 errors
    if (this.state.errors.length > 50) {
      this.state.errors = this.state.errors.slice(-50);
    }
    
    this.saveState();
  }
};
