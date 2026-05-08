import React, { createContext, useContext, useEffect, useState } from 'react';
import { authApi, supabase, usersApi } from '../api';

const AuthContext = createContext(null);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const AUTH_INIT_TIMEOUT_MS = 6000;

  const isAuthLockError = (err) =>
    typeof err?.message === 'string' &&
    err.message.includes('auth-token') &&
    err.message.toLowerCase().includes('lock');

  const safeGetSession = async () => {
    try {
      return await supabase.auth.getSession();
    } catch (err) {
      if (!isAuthLockError(err)) throw err;
      await new Promise((resolve) => setTimeout(resolve, 120));
      return supabase.auth.getSession();
    }
  };

  const syncSession = async () => {
    const {
      data: { session },
      error,
    } = await safeGetSession();

    if (error || !session?.access_token) {
      localStorage.removeItem('token');
      setUser(null);
      return;
    }

    localStorage.setItem('token', session.access_token);

    try {
      const data = await authApi.getMe();
      setUser(data.user);
    } catch (err) {
      console.error('Failed to restore auth session:', err);
      localStorage.removeItem('token');
      setUser(null);
    }
  };

  useEffect(() => {
    let mounted = true;

    const initializeAuth = async () => {
      if (!localStorage.getItem('token')) {
        if (mounted) setLoading(false);
        return;
      }

      try {
        await Promise.race([
          syncSession(),
          new Promise((_, reject) =>
            setTimeout(() => reject(new Error('Auth initialization timeout')), AUTH_INIT_TIMEOUT_MS)
          ),
        ]);
      } catch (err) {
        localStorage.removeItem('token');
        setUser(null);
      } finally {
        if (mounted) {
          setLoading(false);
        }
      }
    };

    initializeAuth();

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, session) => {
      try {
        if (!session?.access_token) {
          localStorage.removeItem('token');
          setUser(null);
          return;
        }

        localStorage.setItem('token', session.access_token);
        const data = await authApi.getMe();
        setUser(data.user);
      } catch (err) {
        if (isAuthLockError(err)) {
          return;
        }
        console.error('Auth state sync error:', err);
        localStorage.removeItem('token');
        setUser(null);
      }
    });

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);

  const login = async (email, password) => {
    const data = await authApi.login(email, password);
    if (data?.token) {
      localStorage.setItem('token', data.token);
    }
    setUser(data.user);
    return data;
  };

  const register = async (email, password, name, role) => {
    const data = await authApi.register(email, password, name, role);
    if (data?.token) {
      localStorage.setItem('token', data.token);
    }
    setUser(data.user);
    return data;
  };

  const logout = async () => {
    try {
      await usersApi.markOffline();
    } catch (err) {
      console.error('Error marking user offline:', err);
    } finally {
      await supabase.auth.signOut();
      localStorage.removeItem('token');
      setUser(null);
    }
  };

  const value = {
    user,
    loading,
    login,
    register,
    logout,
    isManager: user?.role === 'manager',
    isWorker: user?.role === 'worker',
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
