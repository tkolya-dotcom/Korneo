
import { repositories } from './api.js';
import { authService } from './auth.js';
import { APP_CONFIG } from './config.js';

export class ChatService {
  constructor() {
    this.chatsRepo = repositories.chats;
    this.messagesRepo = repositories.messages;
  }

  async getUserChats(userId) {
    try {
      return await this.chatsRepo.getUserChats(userId);
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ С‡Р°С‚РѕРІ:', error);
      throw error;
    }
  }

  async createChat(name, type = 'private', memberIds = []) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      }

      const chat = await this.chatsRepo.create({
        name,
        type,
        created_by: currentUser.id
      });

      await this.addMember(chat.id, currentUser.id);

      for (const memberId of memberIds) {
        if (memberId !== currentUser.id) {
          await this.addMember(chat.id, memberId);
        }
      }

      return chat;
    } catch (error) {
      console.error('РћС€РёР±РєР° СЃРѕР·РґР°РЅРёСЏ С‡Р°С‚Р°:', error);
      throw error;
    }
  }

  async addMember(chatId, userId) {
    try {
      if (!window.supabaseClient) {
        throw new Error('Supabase client РЅРµ РёРЅРёС†РёР°Р»РёР·РёСЂРѕРІР°РЅ');
      }

      const supabase = window.supabaseClient;

      const { error } = await supabase
        .from('chat_members')
        .upsert([{ chat_id: chatId, user_id: userId, joined_at: new Date().toISOString() }]);

      if (error) {
        console.error('Supabase error:', error);
        throw new Error(`РќРµ СѓРґР°Р»РѕСЃСЊ РґРѕР±Р°РІРёС‚СЊ СѓС‡Р°СЃС‚РЅРёРєР°: ${error.message}`);
      }

      console.log('вњ… РЈС‡Р°СЃС‚РЅРёРє РґРѕР±Р°РІР»РµРЅ:', userId);
      return true;
    } catch (error) {
      console.error('РћС€РёР±РєР° РґРѕР±Р°РІР»РµРЅРёСЏ СѓС‡Р°СЃС‚РЅРёРєР°:', error);
      throw error;
    }
  }

  async removeMember(chatId, userId) {
    try {
      if (!window.supabaseClient) {
        throw new Error('Supabase client РЅРµ РёРЅРёС†РёР°Р»РёР·РёСЂРѕРІР°РЅ');
      }

      const supabase = window.supabaseClient;

      const { error } = await supabase
        .from('chat_members')
        .delete()
        .eq('chat_id', chatId)
        .eq('user_id', userId);

      if (error) throw error;
      return true;
    } catch (error) {
      console.error('РћС€РёР±РєР° СѓРґР°Р»РµРЅРёСЏ СѓС‡Р°СЃС‚РЅРёРєР°:', error);
      throw error;
    }
  }

  async sendMessage(chatId, content, type = 'text', replyToId = null) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      }

      const message = {
        chat_id: chatId,
        sender_id: currentUser.id,
        content: typeof content === 'string' ? content : JSON.stringify(content),
        type,
        reply_to_id: replyToId
      };

      return await this.messagesRepo.create(message);
    } catch (error) {
      console.error('РћС€РёР±РєР° РѕС‚РїСЂР°РІРєРё СЃРѕРѕР±С‰РµРЅРёСЏ:', error);
      throw error;
    }
  }

  async getMessages(chatId, limit = 50) {
    try {
      return await this.messagesRepo.getByChat(chatId, limit);
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ СЃРѕРѕР±С‰РµРЅРёР№:', error);
      throw error;
    }
  }

  async deleteMessageForMe(messageId) {
    try {
      const currentUser = authService.getCurrentUser();
      const supabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );

      const { data: message } = await supabase
        .from('messages')
        .select('deleted_for')
        .eq('id', messageId)
        .single();

      const deletedFor = message?.deleted_for || [];
      
      if (!deletedFor.includes(currentUser.id)) {
        deletedFor.push(currentUser.id);
      }

      const { error } = await supabase
        .from('messages')
        .update({ deleted_for: deletedFor })
        .eq('id', messageId);

      if (error) throw error;
      return true;
    } catch (error) {
      console.error('РћС€РёР±РєР° СѓРґР°Р»РµРЅРёСЏ СЃРѕРѕР±С‰РµРЅРёСЏ:', error);
      throw error;
    }
  }

  async deleteMessageForAll(messageId) {
    try {
      const currentUser = authService.getCurrentUser();
      const message = await this.messagesRepo.getById(messageId);

      if (!message) {
        throw new Error('РЎРѕРѕР±С‰РµРЅРёРµ РЅРµ РЅР°Р№РґРµРЅРѕ');
      }

      const canDelete = 
        message.sender_id === currentUser?.id ||
        authService.hasRole([APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN]);

      if (!canDelete) {
        throw new Error('РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ');
      }

      return await this.messagesRepo.delete(messageId);
    } catch (error) {
      console.error('РћС€РёР±РєР° СѓРґР°Р»РµРЅРёСЏ СЃРѕРѕР±С‰РµРЅРёСЏ Сѓ РІСЃРµС…:', error);
      throw error;
    }
  }

  async markAsRead(messageId) {
    try {
      const currentUser = authService.getCurrentUser();
      return await this.messagesRepo.markAsRead(messageId, currentUser.id);
    } catch (error) {
      console.error('РћС€РёР±РєР° РѕС‚РјРµС‚РєРё РїСЂРѕС‡С‚РµРЅРёСЏ:', error);
      throw error;
    }
  }

  subscribeToChat(chatId, callback) {
    if (!window.supabaseClient) {
      console.error('Supabase client РЅРµ РёРЅРёС†РёР°Р»РёР·РёСЂРѕРІР°РЅ');
      return () => {};
    }

    const supabase = window.supabaseClient;

    const channel = supabase
      .channel(`chat_${chatId}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'messages',
          filter: `chat_id=eq.${chatId}`
        },
        (payload) => {
          callback(payload);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }

  subscribeToNewChats(userId, callback) {
    const supabase = window.supabase.createClient(
      window.SUPABASE_CONFIG.url,
      window.SUPABASE_CONFIG.anonKey
    );

    const channel = supabase
      .channel('new_chats')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'chat_members'
        },
        async (payload) => {
          const newChatId = payload.new.chat_id;
          
          const chat = await this.chatsRepo.getById(newChatId);
          const members = await this.getChatMembers(newChatId);
          
          if (members.some(m => m.user_id === userId)) {
            callback({ ...payload, chat });
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }

  async getChatMembers(chatId) {
    try {
      if (!window.supabaseClient) {
        throw new Error('Supabase client РЅРµ РёРЅРёС†РёР°Р»РёР·РёСЂРѕРІР°РЅ');
      }

      const supabase = window.supabaseClient;

      const { data, error } = await supabase
        .from('chat_members')
        .select(`
          user_id,
          joined_at,
          role,
          users!inner(user_id)(id, name, email, role, is_online)
        `)
        .eq('chat_id', chatId);

      if (error) {
        console.error('getChatMembers error:', error);
        throw error;
      }
      return (data || []).map(m => ({ ...m, user: m.users[0] || null }));
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ СѓС‡Р°СЃС‚РЅРёРєРѕРІ:', error);
      throw error;
    }
  }

  async pinChat(chatId, userId) {
    try {
      const supabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );

      const { error } = await supabase
        .from('chat_members')
        .upsert({ 
          chat_id: chatId, 
          user_id: userId,
          is_pinned: true 
        }, {
          onConflict: 'chat_id,user_id'
        });

      if (error) throw error;
      return true;
    } catch (error) {
      console.error('РћС€РёР±РєР° Р·Р°РєСЂРµРїР»РµРЅРёСЏ С‡Р°С‚Р°:', error);
      throw error;
    }
  }

  async unpinChat(chatId, userId) {
    try {
      const supabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );

      const { error } = await supabase
        .from('chat_members')
        .update({ is_pinned: false })
        .eq('chat_id', chatId)
        .eq('user_id', userId);

      if (error) throw error;
      return true;
    } catch (error) {
      console.error('РћС€РёР±РєР° РѕС‚РєСЂРµРїР»РµРЅРёСЏ С‡Р°С‚Р°:', error);
      throw error;
    }
  }

  async muteChat(chatId, userId) {
    try {
      const supabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );

      const { error } = await supabase
        .from('chat_members')
        .upsert({ 
          chat_id: chatId, 
          user_id: userId,
          is_muted: true 
        }, {
          onConflict: 'chat_id,user_id'
        });

      if (error) throw error;
      return true;
    } catch (error) {
      console.error('РћС€РёР±РєР° РѕС‚РєР»СЋС‡РµРЅРёСЏ СѓРІРµРґРѕРјР»РµРЅРёР№:', error);
      throw error;
    }
  }

  async unmuteChat(chatId, userId) {
    try {
      const supabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );

      const { error } = await supabase
        .from('chat_members')
        .update({ is_muted: false })
        .eq('chat_id', chatId)
        .eq('user_id', userId);

      if (error) throw error;
      return true;
    } catch (error) {
      console.error('РћС€РёР±РєР° РІРєР»СЋС‡РµРЅРёСЏ СѓРІРµРґРѕРјР»РµРЅРёР№:', error);
      throw error;
    }
  }
}

export const chatService = new ChatService();

if (typeof window !== 'undefined') {
  window.chatService = chatService;
}
