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
      setError('РћС€РёР±РєР° Р·Р°РіСЂСѓР·РєРё СЃС‚Р°С‚СѓСЃРѕРІ');
    } finally {
      setLoading(false);
    }
  }, []);

  const sendHeartbeat = useCallback(async () => {
    try {
      await usersApi.heartbeat();
    } catch (err) {
      console.error('Heartbeat error:', err);
    }
  }, []);

  useEffect(() => {
    sendHeartbeat();

    loadUsersStatus();

    const statusInterval = setInterval(loadUsersStatus, 15000);

    const heartbeatInterval = setInterval(sendHeartbeat, 30000);

    const handleBeforeUnload = () => {
      usersApi.markOffline().catch(console.error);
    };

    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        sendHeartbeat();
        loadUsersStatus();
      }
    };

    window.addEventListener('beforeunload', handleBeforeUnload);
    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      clearInterval(statusInterval);
      clearInterval(heartbeatInterval);
      window.removeEventListener('beforeunload', handleBeforeUnload);
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [loadUsersStatus, sendHeartbeat]);

  const getRoleLabel = (role) => {
    const labels = {
      manager: 'Р СѓРєРѕРІРѕРґРёС‚РµР»СЊ',
      worker: 'РСЃРїРѕР»РЅРёС‚РµР»СЊ',
      deputy_head: 'Р—Р°Рј. СЂСѓРєРѕРІРѕРґРёС‚РµР»СЏ'
    };
    return labels[role] || role;
  };

  const formatLastSeen = (lastSeenAt) => {
    if (!lastSeenAt) return 'РЅРµРёР·РІРµСЃС‚РЅРѕ';
    
    const lastSeen = new Date(lastSeenAt);
    const now = new Date();
    const diffMs = now - lastSeen;
    const diffMins = Math.floor(diffMs / 60000);
    
    if (diffMins < 1) return 'С‚РѕР»СЊРєРѕ С‡С‚Рѕ';
    if (diffMins < 60) return `${diffMins} РјРёРЅ. РЅР°Р·Р°Рґ`;
    
    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours} С‡. РЅР°Р·Р°Рґ`;
    
    return lastSeen.toLocaleDateString('ru-RU');
  };

  if (loading) {
    return (
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">РџРѕР»СЊР·РѕРІР°С‚РµР»Рё</h3>
        </div>
        <div className="loading">Р—Р°РіСЂСѓР·РєР°...</div>
      </div>
    );
  }

  return (
    <div className="card">
      <div className="card-header">
        <h3 className="card-title">РџРѕР»СЊР·РѕРІР°С‚РµР»Рё</h3>
        <div className="user-status-counts">
          <span className="online-count">
            <span className="status-dot online"></span>
            РћРЅР»Р°Р№РЅ: {usersStatus.onlineCount}
          </span>
          <span className="offline-count">
            <span className="status-dot offline"></span>
            РћС„Р»Р°Р№РЅ: {usersStatus.offlineCount}
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
              РћРЅР»Р°Р№РЅ ({usersStatus.onlineCount})
            </h4>
            <ul className="user-list">
              {usersStatus.onlineUsers.map((u) => (
                <li key={u.id} className="user-item online">
                  <div className="user-info">
                    <span className="user-name">
                      {u.display_name || u.email}
                      {u.id === user?.id && <span className="you-badge"> (РІС‹)</span>}
                    </span>
                    <span className="user-role">{getRoleLabel(u.role)}</span>
                  </div>
                  <span className="status-indicator online">РћРЅР»Р°Р№РЅ</span>
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
              РћС„Р»Р°Р№РЅ ({usersStatus.offlineCount})
            </h4>
            <ul className="user-list">
              {usersStatus.offlineUsers.map((u) => (
                <li key={u.id} className="user-item offline">
                  <div className="user-info">
                    <span className="user-name">
                      {u.display_name || u.email}
                      {u.id === user?.id && <span className="you-badge"> (РІС‹)</span>}
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
            <p>РќРµС‚ РїРѕР»СЊР·РѕРІР°С‚РµР»РµР№</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default UserStatusCard;

