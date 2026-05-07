
import { getSupabase, repositories } from './api.js';
import { APP_CONFIG } from './config.js';

const { roles } = APP_CONFIG;

export class AuthService {
  constructor() {
    this.supabase = getSupabase();
    this.currentUser = null;
    this.userProfile = null;
  }

  async signIn(email, password) {
    try {
      const { data, error } = await this.supabase.auth.signInWithPassword({
        email,
        password,
        options: {
          redirectTo: window.location.origin
        }
      });

      if (error) throw error;

      this.currentUser = data.user;
      this.userProfile = await repositories.users.getCurrentUser();
      
      localStorage.setItem('user_id', data.user.id);
      localStorage.setItem('user_role', this.userProfile?.role || 'worker');
      
      console.log('вњ… Р’С…РѕРґ РІС‹РїРѕР»РЅРµРЅ:', email);
      return { success: true, user: data.user, profile: this.userProfile };
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° РІС…РѕРґР°:', error.message);
      return { 
        success: false, 
        error: this._mapAuthError(error) 
      };
    }
  }

  async signUp(email, password, name, role = 'worker') {
    try {
      if (['manager', 'deputy_head', 'admin'].includes(role)) {
        return {
          success: false,
          error: 'Р РµРіРёСЃС‚СЂР°С†РёСЏ РЅР° СЌС‚Сѓ СЂРѕР»СЊ РЅРµРІРѕР·РјРѕР¶РЅР°'
        };
      }

      const { data, error } = await this.supabase.auth.signUp({
        email,
        password,
        options: {
          redirectTo: window.location.origin,
          data: {
            name,
            role
          }
        }
      });

      if (error) throw error;

      console.log('вњ… Р РµРіРёСЃС‚СЂР°С†РёСЏ РІС‹РїРѕР»РЅРµРЅР°:', email);
      return { success: true, user: data.user };
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° СЂРµРіРёСЃС‚СЂР°С†РёРё:', error.message);
      return { 
        success: false, 
        error: this._mapAuthError(error) 
      };
    }
  }

  async signOut() {
    try {
      if (this.currentUser?.id) {
        await repositories.users.setOffline(this.currentUser.id);
      }

      await this.supabase.auth.signOut();
      
      localStorage.removeItem('user_id');
      localStorage.removeItem('user_role');
      localStorage.removeItem('current_task_filter');
      
      this.currentUser = null;
      this.userProfile = null;
      
      console.log('вњ… Р’С‹С…РѕРґ РІС‹РїРѕР»РЅРµРЅ');
      return { success: true };
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° РІС‹С…РѕРґР°:', error.message);
      return { success: false, error: error.message };
    }
  }

  async checkSession() {
    try {
      const { data: { session } } = await this.supabase.auth.getSession();
      
      if (!session) {
        return { authenticated: false };
      }

      this.currentUser = session.user;
      this.userProfile = await repositories.users.getCurrentUser();
      
      if (this.userProfile) {
        await repositories.users.updateLastSeen(this.currentUser.id);
      }

      localStorage.setItem('user_id', this.currentUser.id);
      localStorage.setItem('user_role', this.userProfile?.role || 'worker');

      return {
        authenticated: true,
        user: this.currentUser,
        profile: this.userProfile
      };
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° РїСЂРѕРІРµСЂРєРё СЃРµСЃСЃРёРё:', error.message);
      return { authenticated: false, error: error.message };
    }
  }

  getCurrentUser() {
    return this.currentUser;
  }

  getUserProfile() {
    return this.userProfile;
  }

  hasRole(requiredRoles) {
    if (!this.userProfile) return false;
    
    const userRole = this.userProfile.role;
    
    if (Array.isArray(requiredRoles)) {
      return requiredRoles.includes(userRole);
    }
    
    return userRole === requiredRoles;
  }

  canCreateTasks() {
    return this.hasRole([roles.ENGINEER, roles.MANAGER, roles.DEPUTY_HEAD, roles.ADMIN]);
  }

  canDeleteTasks() {
    return this.hasRole([roles.MANAGER, roles.DEPUTY_HEAD, roles.ADMIN]);
  }

  canManageUsers() {
    return this.hasRole([roles.MANAGER, roles.DEPUTY_HEAD, roles.ADMIN]);
  }

  canApproveRequests() {
    return this.hasRole([roles.MANAGER, roles.DEPUTY_HEAD, roles.ADMIN]);
  }

  async updatePassword(newPassword) {
    try {
      const { error } = await this.supabase.auth.updateUser({
        password: newPassword
      });

      if (error) throw error;

      console.log('вњ… РџР°СЂРѕР»СЊ РёР·РјРµРЅС‘РЅ');
      return { success: true };
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° СЃРјРµРЅС‹ РїР°СЂРѕР»СЏ:', error.message);
      return { success: false, error: error.message };
    }
  }

  async resetPassword(email) {
    try {
      const { error } = await this.supabase.auth.resetPasswordForEmail(email, {
        redirectTo: window.location.origin + '/reset-password'
      });

      if (error) throw error;

      console.log('вњ… РџРёСЃСЊРјРѕ РґР»СЏ СЃР±СЂРѕСЃР° РѕС‚РїСЂР°РІР»РµРЅРѕ');
      return { success: true };
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° РІРѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёСЏ РїР°СЂРѕР»СЏ:', error.message);
      return { success: false, error: error.message };
    }
  }

  onAuthStateChange(callback) {
    return this.supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_IN' && session) {
        this.currentUser = session.user;
        this.userProfile = await repositories.users.getCurrentUser();
      } else if (event === 'SIGNED_OUT') {
        this.currentUser = null;
        this.userProfile = null;
      }
      
      callback(event, session);
    });
  }

  _mapAuthError(error) {
    const errorMessages = {
      'Invalid login credentials': 'РќРµРІРµСЂРЅС‹Р№ email РёР»Рё РїР°СЂРѕР»СЊ',
      'Email not confirmed': 'Email РЅРµ РїРѕРґС‚РІРµСЂР¶РґС‘РЅ',
      'User already registered': 'РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ СѓР¶Рµ СЃСѓС‰РµСЃС‚РІСѓРµС‚',
      'Weak password': 'РЎР»РёС€РєРѕРј СЃР»Р°Р±С‹Р№ РїР°СЂРѕР»СЊ (РјРёРЅ. 6 СЃРёРјРІРѕР»РѕРІ)',
      'Over request rate limit': 'РЎР»РёС€РєРѕРј РјРЅРѕРіРѕ Р·Р°РїСЂРѕСЃРѕРІ, РїРѕРїСЂРѕР±СѓР№С‚Рµ РїРѕР·Р¶Рµ'
    };

    return errorMessages[error.message] || error.message;
  }
}

export class UserProfileService {
  constructor() {
    this.authService = new AuthService();
  }

  async updateProfile(updates) {
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser) {
        throw new Error('РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      }

      const updated = await repositories.users.update(currentUser.id, updates);
      
      this.authService.userProfile = updated;
      
      console.log('вњ… РџСЂРѕС„РёР»СЊ РѕР±РЅРѕРІР»С‘РЅ');
      return { success: true, profile: updated };
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° РѕР±РЅРѕРІР»РµРЅРёСЏ РїСЂРѕС„РёР»СЏ:', error.message);
      return { success: false, error: error.message };
    }
  }

  async uploadAvatar(file) {
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser) {
        throw new Error('РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      }

      const fileExt = file.name.split('.').pop();
      const fileName = `${currentUser.id}.${fileExt}`;
      
      const { data, error } = await this.authService.supabase.storage
        .from('avatars')
        .upload(fileName, file, { upsert: true });

      if (error) throw error;

      const { data: { publicUrl } } = this.authService.supabase.storage
        .from('avatars')
        .getPublicUrl(fileName);

      return await this.updateProfile({ avatar_url: publicUrl });
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° Р·Р°РіСЂСѓР·РєРё Р°РІР°С‚Р°СЂР°:', error.message);
      return { success: false, error: error.message };
    }
  }

  async updateFCMToken(token) {
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser) {
        throw new Error('РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      }

      return await repositories.users.update(currentUser.id, {
        fcm_token: token
      });
    } catch (error) {
      console.error('вќЊ РћС€РёР±РєР° РѕР±РЅРѕРІР»РµРЅРёСЏ FCM С‚РѕРєРµРЅР°:', error.message);
      return null;
    }
  }
}

export const authService = new AuthService();
export const userProfileService = new UserProfileService();

if (typeof window !== 'undefined') {
  window.authService = authService;
  window.userProfileService = userProfileService;
}
