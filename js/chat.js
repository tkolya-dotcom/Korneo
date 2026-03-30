/**
 * Управление чатом и сообщениями
 */

import { repositories } from './api.js';
import { authService } from './auth.js';
import { APP_CONFIG } from './config.js';

/**
 * Сервис управления чатами
 */
export class ChatService {
  constructor() {
    this.chatsRepo = repositories.chats;
    this.messagesRepo = repositories.messages;
  }

  /**
   * Получение всех чатов пользователя
   */
  async getUserChats(userId) {
    try {
      return await this.chatsRepo.getUserChats(userId);
    } catch (error) {
      console.error('Ошибка получения чатов:', error);
      throw error;
    }
  }

  /**
   * Создание нового чата
   */
  async createChat(name, type = 'private', memberIds = []) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('Пользователь не авторизован');
      }

      // Создаём чат
      const chat = await this.chatsRepo.create({
        name,
        type,
        created_by: currentUser.id
      });

      // Добавляем создателя
      await this.addMember(chat.id, currentUser.id);

      // Добавляем остальных участников
      for (const memberId of memberIds) {
        if (memberId !== currentUser.id) {
          await this.addMember(chat.id, memberId);
        }
      }

      return chat;
    } catch (error) {
      console.error('Ошибка создания чата:', error);
      throw error;
    }
  }

  /**
   * Добавление участника в чат
   */
  async addMember(chatId, userId) {
    try {
      if (!window.supabaseClient) {
        throw new Error('Supabase client не инициализирован');
      }

      const supabase = window.supabaseClient;

      const { error } = await supabase
        .from('chat_members')
        .upsert([{ chat_id: chatId, user_id: userId, joined_at: new Date().toISOString() }]);

      if (error) {
        console.error('Supabase error:', error);
        throw new Error(`Не удалось добавить участника: ${error.message}`);
      }

      console.log('✅ Участник добавлен:', userId);
      return true;
    } catch (error) {
      console.error('Ошибка добавления участника:', error);
      throw error;
    }
  }

  /**
   * Удаление участника из чата
   */
  async removeMember(chatId, userId) {
    try {
      if (!window.supabaseClient) {
        throw new Error('Supabase client не инициализирован');
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
      console.error('Ошибка удаления участника:', error);
      throw error;
    }
  }

  /**
   * Отправка сообщения
   */
  async sendMessage(chatId, content, type = 'text', replyToId = null) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('Пользователь не авторизован');
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
      console.error('Ошибка отправки сообщения:', error);
      throw error;
    }
  }

  /**
   * Получение сообщений чата
   */
  async getMessages(chatId, limit = 50) {
    try {
      return await this.messagesRepo.getByChat(chatId, limit);
    } catch (error) {
      console.error('Ошибка получения сообщений:', error);
      throw error;
    }
  }

  /**
   * Удаление сообщения (у себя)
   */
  async deleteMessageForMe(messageId) {
    try {
      const currentUser = authService.getCurrentUser();
      const supabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );

      // Добавляем user_id в deleted_for
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
      console.error('Ошибка удаления сообщения:', error);
      throw error;
    }
  }

  /**
   * Удаление сообщения у всех (только автор или manager)
   */
  async deleteMessageForAll(messageId) {
    try {
      const currentUser = authService.getCurrentUser();
      const message = await this.messagesRepo.getById(messageId);

      if (!message) {
        throw new Error('Сообщение не найдено');
      }

      // Проверка прав
      const canDelete = 
        message.sender_id === currentUser?.id ||
        authService.hasRole([APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN]);

      if (!canDelete) {
        throw new Error('Недостаточно прав');
      }

      return await this.messagesRepo.delete(messageId);
    } catch (error) {
      console.error('Ошибка удаления сообщения у всех:', error);
      throw error;
    }
  }

  /**
   * Отметка сообщения как прочитанное
   */
  async markAsRead(messageId) {
    try {
      const currentUser = authService.getCurrentUser();
      return await this.messagesRepo.markAsRead(messageId, currentUser.id);
    } catch (error) {
      console.error('Ошибка отметки прочтения:', error);
      throw error;
    }
  }

  /**
   * Подписка на сообщения чата (Realtime)
   */
  subscribeToChat(chatId, callback) {
    if (!window.supabaseClient) {
      console.error('Supabase client не инициализирован');
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

  /**
   * Подписка на новые чаты
   */
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
          
          // Проверяем, является ли пользователь участником
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

  /**
   * Получение участников чата
   */
  async getChatMembers(chatId) {
    try {
      if (!window.supabaseClient) {
        throw new Error('Supabase client не инициализирован');
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
      console.error('Ошибка получения участников:', error);
      throw error;
    }
  }

  /**
   * Закрепление чата
   */
  async pinChat(chatId, userId) {
    try {
      const supabase = window.supabase.createClient(
        window.SUPABASE_CONFIG.url,
        window.SUPABASE_CONFIG.anonKey
      );

      // Используем upsert для обновления или создания записи
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
      console.error('Ошибка закрепления чата:', error);
      throw error;
    }
  }

  /**
   * Открепление чата
   */
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
      console.error('Ошибка открепления чата:', error);
      throw error;
    }
  }

  /**
   * Отключение уведомлений чата
   */
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
      console.error('Ошибка отключения уведомлений:', error);
      throw error;
    }
  }

  /**
   * Включение уведомлений чата
   */
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
      console.error('Ошибка включения уведомлений:', error);
      throw error;
    }
  }
}

// Экспорт экземпляра
export const chatService = new ChatService();

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.chatService = chatService;
}
