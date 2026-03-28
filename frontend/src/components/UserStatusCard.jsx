import React, { useState, useEffect, useCallback } from 'react';
import { usersApi } from '../api';
import { useAuth } from '../context/AuthContext';

const UserStatusCard = () => {
  const { user } = useAuth();
  const [usersStatus, setUsersStatus] = useState({
    onlineUsers: [],
    offlineUsers: [],
    onlineCount: 0,
    offlineCount: 0
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Function to load users status
  const loadUsersStatus = useCallback(async () => {
    try {
      const data = await usersApi.getStatus();
      setUsersStatus({
        onlineUsers: data.onlineUsers || [],
        offlineUsers: data.offlineUsers || [],
        onlineCount: data.onlineCount || 0,
        offlineCount: data.offlineCount || 0
      });
      setError(null);
    } catch (err) {
      console.error('Error loading users status:', err);
      setError('Ошибка загрузки статусов');
    } finally {
      setLoading(false);
    }
  }, []);

  // Function to send heartbeat
  const sendHeartbeat = useCallback(async () => {
    try {
      await usersApi.heartbeat();
    } catch (err) {
      console.error('Heartbeat error:', err);
    }
  }, []);

  // Initial load and setup polling
  useEffect(() => {
    // Send initial heartbeat
    sendHeartbeat();

    // Load users status
    loadUsersStatus();

    // Set up polling for status updates (every 15 seconds)
    const statusInterval = setInterval(loadUsersStatus, 15000);

    // Set up heartbeat interval (every 30 seconds)
    const heartbeatInterval = setInterval(sendHeartbeat, 30000);

    // Handle page unload - mark as offline
    const handleBeforeUnload = () => {
      usersApi.markOffline().catch(console.error);
    };

    // Handle visibility change (tab switch)
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        // Tab became visible - refresh status and heartbeat
        sendHeartbeat();
        loadUsersStatus();
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    document.addEventListener('visibilitychange', handleVisibilityChange);

    // Cleanup
    return () => {
      clearInterval(statusInterval);
      clearInterval(heartbeatInterval);
      window.removeEventListener('beforeunload', handleBeforeUnload);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [loadUsersStatus, sendHeartbeat]);

  const getRoleLabel = (role) => {
    const labels = {
      manager: 'Руководитель',
      worker: 'Исполнитель',
      deputy_head: 'Зам. руководителя'
    };
    return labels[role] || role;
  };

  const formatLastSeen = (lastSeenAt) => {
    if (!lastSeenAt) return 'неизвестно';
    
    const lastSeen = new Date(lastSeenAt);
    const now = new Date();
    const diffMs = now - lastSeen;
    const diffMins = Math.floor(diffMs / 60000);
    
    if (diffMins < 1) return 'только что';
    if (diffMins < 60) return `${diffMins} мин. назад`;
    
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours} ч. назад`;
    
    return lastSeen.toLocaleDateString('ru-RU');
  };

  if (loading) {
    return (
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Пользователи</h3>
        </div>
        <div className="loading">Загрузка...</div>
      </div>
    );
  }

  return (
    <div className="card">
      <div className="card-header">
        <h3 className="card-title">Пользователи</h3>
        <div className="user-status-counts">
          <span className="online-count">
            <span className="status-dot online"></span>
            Онлайн: {usersStatus.onlineCount}
          </span>
          <span className="offline-count">
            <span className="status-dot offline"></span>
            Офлайн: {usersStatus.offlineCount}
          </span>
        </div>
      </div>

      {error && <div className="error">{error}</div>}

      <div className="user-status-list">
        {/* Online Users */}
        {usersStatus.onlineUsers.length > 0 && (
          <div className="user-status-section">
            <h4 className="user-status-section-title">
              <span className="status-dot online"></span>
              Онлайн ({usersStatus.onlineCount})
            </h4>
            <ul className="user-list">
              {usersStatus.onlineUsers.map((u) => (
                <li key={u.id} className="user-item online">
                  <div className="user-info">
                    <span className="user-name">
                      {u.display_name || u.email}
                      {u.id === user?.id && <span className="you-badge"> (вы)</span>}
                    </span>
                    <span className="user-role">{getRoleLabel(u.role)}</span>
                  </div>
                  <span className="status-indicator online">Онлайн</span>
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Offline Users */}
        {usersStatus.offlineUsers.length > 0 && (
          <div className="user-status-section">
            <h4 className="user-status-section-title">
              <span className="status-dot offline"></span>
              Офлайн ({usersStatus.offlineCount})
            </h4>
            <ul className="user-list">
              {usersStatus.offlineUsers.map((u) => (
                <li key={u.id} className="user-item offline">
                  <div className="user-info">
                    <span className="user-name">
                      {u.display_name || u.email}
                      {u.id === user?.id && <span className="you-badge"> (вы)</span>}
                    </span>
                    <span className="user-role">{getRoleLabel(u.role)}</span>
                  </div>
                  <span className="last-seen" title={u.last_seen_at ? new Date(u.last_seen_at).toLocaleString('ru-RU') : ''}>
                    {formatLastSeen(u.last_seen_at)}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* Empty state */}
        {usersStatus.onlineUsers.length === 0 && usersStatus.offlineUsers.length === 0 && (
          <div className="empty-state">
            <p>Нет пользователей</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default UserStatusCard;

