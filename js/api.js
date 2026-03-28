/**
 * Supabase API клиент
 * Обёртка над Supabase JS SDK
 */

import { SUPABASE_CONFIG } from './config.js';

// Импортируем Supabase клиент (через CDN для браузера)
let supabase = null;

/**
 * Инициализация Supabase клиента
 */
export function initSupabase() {
  if (!supabase) {
    // Для браузерной версии используем глобальный объект
    if (window.supabase) {
      supabase = window.supabase.createClient(
        SUPABASE_CONFIG.url,
        SUPABASE_CONFIG.anonKey
      );
    } else {
      console.error('❌ Supabase SDK не загружен!');
      throw new Error('Supabase SDK not loaded');
    }
  }
  return supabase;
}

/**
 * Получить экземпляр клиента
 */
export function getSupabase() {
  if (!supabase) {
    return initSupabase();
  }
  return supabase;
}

/**
 * Базовый CRUD класс для работы с таблицами
 */
export class BaseRepository {
  constructor(tableName) {
    this.tableName = tableName;
    this.supabase = getSupabase();
  }

  /**
   * Получить все записи
   */
  async getAll(options = {}) {
    try {
      let query = this.supabase.from(this.tableName).select('*');
      
      // Применение фильтров
      if (options.filter) {
        Object.entries(options.filter).forEach(([key, value]) => {
          query = query.eq(key, value);
        });
      }
      
      // Сортировка
      if (options.sortBy) {
        query = query.order(options.sortBy.field, { 
          ascending: options.sortBy.ascending !== false 
        });
      }
      
      const { data, error } = await query;
      
      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error(`Error getting all from ${this.tableName}:`, error);
      throw error;
    }
  }

  /**
   * Получить запись по ID
   */
  async getById(id) {
    try {
      const { data, error } = await this.supabase
        .from(this.tableName)
        .select('*')
        .eq('id', id)
        .single();
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error(`Error getting ${this.tableName} by ID:`, error);
      throw error;
    }
  }

  /**
   * Создать запись
   */
  async create(record) {
    try {
      const { data, error } = await this.supabase
        .from(this.tableName)
        .insert([record])
        .select()
        .single();
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error(`Error creating ${this.tableName}:`, error);
      throw error;
    }
  }

  /**
   * Обновить запись
   */
  async update(id, updates) {
    try {
      const { data, error } = await this.supabase
        .from(this.tableName)
        .update(updates)
        .eq('id', id)
        .select()
        .single();
      
      if (error) throw error;
      return data;
    } catch (error) {
      console.error(`Error updating ${this.tableName}:`, error);
      throw error;
    }
  }

  /**
   * Удалить запись
   */
  async delete(id) {
    try {
      const { error } = await this.supabase
        .from(this.tableName)
        .delete()
        .eq('id', id);
      
      if (error) throw error;
      return true;
    } catch (error) {
      console.error(`Error deleting ${this.tableName}:`, error);
      throw error;
    }
  }

  /**
   * Поиск записей
   */
  async search(filters, options = {}) {
    try {
      let query = this.supabase.from(this.tableName).select('*');
      
      // Применение фильтров
      Object.entries(filters).forEach(([key, value]) => {
        if (Array.isArray(value)) {
          query = query.in(key, value);
        } else if (typeof value === 'object') {
          // Операторы: { gt: 5 }, { gte: 5 }, { lt: 10 }, { lte: 10 }, { like: '%text%' }
          const operator = Object.keys(value)[0];
          const val = value[operator];
          
          switch (operator) {
            case 'gt':
              query = query.gt(key, val);
              break;
            case 'gte':
              query = query.gte(key, val);
              break;
            case 'lt':
              query = query.lt(key, val);
              break;
            case 'lte':
              query = query.lte(key, val);
              break;
            case 'like':
              query = query.like(key, val);
              break;
            case 'ilike':
              query = query.ilike(key, val);
              break;
          }
        } else {
          query = query.eq(key, value);
        }
      });
      
      // Лимит и оффсет
      if (options.limit) {
        query = query.limit(options.limit);
      }
      
      if (options.offset) {
        query = query.range(options.offset, options.offset + (options.limit || 10) - 1);
      }
      
      const { data, error } = await query;
      
      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error(`Error searching ${this.tableName}:`, error);
      throw error;
    }
  }

  /**
   * Подписаться на изменения (Realtime)
   */
  onChanges(callback, filters = {}) {
    const channel = this.supabase
      .channel(`${this.tableName}_changes`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: this.tableName,
          ...filters
        },
        (payload) => {
          callback(payload);
        }
      )
      .subscribe();
    
    return () => {
      this.supabase.removeChannel(channel);
    };
  }
}

/**
 * Специализированные репозитории
 */

// Пользователи
export class UsersRepository extends BaseRepository {
  constructor() {
    super('users');
  }

  async getCurrentUser() {
    const { data: { user } } = await this.supabase.auth.getUser();
    if (!user) return null;
    
    return await this.getById(user.id);
  }

  async getUserRole(userId) {
    const user = await this.getById(userId);
    return user?.role || 'worker';
  }

  async isOnline(userId) {
    const user = await this.getById(userId);
    return user?.is_online || false;
  }

  async updateLastSeen(userId) {
    return await this.update(userId, {
      last_seen_at: new Date().toISOString(),
      is_online: true
    });
  }

  async setOffline(userId) {
    return await this.update(userId, {
      is_online: false
    });
  }
}

// Задачи
export class TasksRepository extends BaseRepository {
  constructor() {
    super('tasks');
  }

  async getByAssignee(assigneeId) {
    return await this.search({ assignee_id: assigneeId });
  }

  async getByStatus(status) {
    return await this.search({ status });
  }

  async getByProject(projectId) {
    return await this.search({ project_id: projectId });
  }

  async updateStatus(taskId, status) {
    const updates = { 
      status,
      updated_at: new Date().toISOString()
    };
    
    if (status === 'completed') {
      updates.finished_at = new Date().toISOString();
    }
    
    return await this.update(taskId, updates);
  }
}

// Проекты
export class ProjectsRepository extends BaseRepository {
  constructor() {
    super('projects');
  }

  async getWithTasksCount() {
    // TODO: Использовать RPC функцию для получения счётчика
    return await this.getAll();
  }
}

// Монтажи
export class InstallationsRepository extends BaseRepository {
  constructor() {
    super('installations');
  }

  async getByStatus(status) {
    return await this.search({ status });
  }

  async getByProject(projectId) {
    return await this.search({ project_id: projectId });
  }
}

// Сообщения
export class MessagesRepository extends BaseRepository {
  constructor() {
    super('messages');
  }

  async getByChat(chatId, limit = 50) {
    const { data, error } = await this.supabase
      .from(this.tableName)
      .select('*')
      .eq('chat_id', chatId)
      .order('created_at', { ascending: true })
      .limit(limit);
    
    if (error) throw error;
    return data || [];
  }

  async markAsRead(messageId, userId) {
    try {
      const { error } = await this.supabase
        .from('message_read_receipts')
        .insert([{ message_id: messageId, user_id: userId }]);
      
      if (error) throw error;
      return true;
    } catch (error) {
      console.error('Error marking message as read:', error);
      throw error;
    }
  }
}

// Чаты
export class ChatsRepository extends BaseRepository {
  constructor() {
    super('chats');
  }

  async getUserChats(userId) {
    const { data, error } = await this.supabase
      .rpc('get_user_chats', { user_id: userId });
    
    if (error) {
      // Fallback: ручное получение через join
      return await this._getUserChatsFallback(userId);
    }
    
    return data || [];
  }

  async _getUserChatsFallback(userId) {
    const { data: members } = await this.supabase
      .from('chat_members')
      .select('chat_id')
      .eq('user_id', userId);
    
    if (!members || members.length === 0) return [];
    
    const chatIds = members.map(m => m.chat_id);
    return await this.search({ id: chatIds });
  }
}

// Комментарии
export class CommentsRepository extends BaseRepository {
  constructor() {
    super('comments');
  }

  async getByEntity(entityType, entityId) {
    return await this.search({ 
      entity_type: entityType,
      entity_id: entityId 
    });
  }

  async addComment(entityType, entityId, userId, content, parentId = null) {
    return await this.create({
      entity_type: entityType,
      entity_id: entityId,
      user_id: userId,
      content,
      parent_comment_id: parentId
    });
  }
}

// Материалы
export class MaterialsRepository extends BaseRepository {
  constructor() {
    super('materials');
  }

  async getByCategory(category) {
    return await this.search({ category });
  }

  async searchByName(name) {
    return await this.search({ name: { ilike: `%${name}%` } });
  }
}

// Заявки на материалы
export class MaterialsRequestsRepository extends BaseRepository {
  constructor() {
    super('materials_requests');
  }

  async getByRequester(requesterId) {
    return await this.search({ requester_id: requesterId });
  }

  async updateStatus(requestId, status) {
    const updates = { 
      status,
      updated_at: new Date().toISOString()
    };
    
    if (status === 'approved') {
      updates.approved_at = new Date().toISOString();
    }
    
    return await this.update(requestId, updates);
  }
}

// Задачи АВР (Аварийно-Восстановительные Работы)
export class TasksAVRRepository extends BaseRepository {
  constructor() {
    super('tasks_avr');
  }
}

/**
 * Экспорт экземпляров репозиториев
 */
export const repositories = {
  users: new UsersRepository(),
  tasks: new TasksRepository(),
  tasksAvr: new TasksAVRRepository(),
  projects: new ProjectsRepository(),
  installations: new InstallationsRepository(),
  messages: new MessagesRepository(),
  chats: new ChatsRepository(),
  comments: new CommentsRepository(),
  materials: new MaterialsRepository(),
  materialsRequests: new MaterialsRequestsRepository()
};

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.repositories = repositories;
  window.BaseRepository = BaseRepository;
}
