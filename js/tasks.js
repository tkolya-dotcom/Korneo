
import { repositories } from './api.js';
import { authService } from './auth.js';
import { APP_CONFIG } from './config.js';

const { taskStatus, priorities } = APP_CONFIG;

export class TaskService {
  constructor() {
    this.repository = repositories.tasks;
  }

  async getTasks(filters = {}) {
    try {
      return await this.repository.search(filters, {
        sortBy: { field: 'created_at', ascending: false }
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ Р·Р°РґР°С‡:', error);
      throw error;
    }
  }

  async getUserTasks(userId) {
    try {
      return await this.repository.getByAssignee(userId);
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ Р·Р°РґР°С‡ РїРѕР»СЊР·РѕРІР°С‚РµР»СЏ:', error);
      throw error;
    }
  }

  async getTask(taskId) {
    try {
      return await this.repository.getById(taskId);
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ Р·Р°РґР°С‡Рё:', error);
      throw error;
    }
  }

  async createTask(taskData) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      }

      if (!authService.canCreateTasks()) {
        throw new Error('РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ РґР»СЏ СЃРѕР·РґР°РЅРёСЏ Р·Р°РґР°С‡');
      }

      const task = {
        ...taskData,
        created_by: currentUser.id,
        status: taskStatus.NEW,
        is_archived: false
      };

      return await this.repository.create(task);
    } catch (error) {
      console.error('РћС€РёР±РєР° СЃРѕР·РґР°РЅРёСЏ Р·Р°РґР°С‡Рё:', error);
      throw error;
    }
  }

  async updateTask(taskId, updates) {
    try {
      const task = await this.getTask(taskId);
      
      if (!task) {
        throw new Error('Р—Р°РґР°С‡Р° РЅРµ РЅР°Р№РґРµРЅР°');
      }

      const currentUser = authService.getCurrentUser();
      
      const canEdit = 
        task.created_by === currentUser?.id ||
        task.assignee_id === currentUser?.id ||
        authService.hasRole([APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN]);

      if (!canEdit) {
        throw new Error('РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ РґР»СЏ СЂРµРґР°РєС‚РёСЂРѕРІР°РЅРёСЏ');
      }

      return await this.repository.update(taskId, {
        ...updates,
        updated_at: new Date().toISOString()
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° РѕР±РЅРѕРІР»РµРЅРёСЏ Р·Р°РґР°С‡Рё:', error);
      throw error;
    }
  }

  async deleteTask(taskId) {
    try {
      if (!authService.canDeleteTasks()) {
        throw new Error('РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ РґР»СЏ СѓРґР°Р»РµРЅРёСЏ Р·Р°РґР°С‡');
      }

      return await this.repository.delete(taskId);
    } catch (error) {
      console.error('РћС€РёР±РєР° СѓРґР°Р»РµРЅРёСЏ Р·Р°РґР°С‡Рё:', error);
      throw error;
    }
  }

  async updateTaskStatus(taskId, newStatus) {
    try {
      return await this.repository.updateStatus(taskId, newStatus);
    } catch (error) {
      console.error('РћС€РёР±РєР° РёР·РјРµРЅРµРЅРёСЏ СЃС‚Р°С‚СѓСЃР°:', error);
      throw error;
    }
  }

  async assignTask(taskId, assigneeId) {
    try {
      return await this.updateTask(taskId, {
        assignee_id: assigneeId
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° РЅР°Р·РЅР°С‡РµРЅРёСЏ РёСЃРїРѕР»РЅРёС‚РµР»СЏ:', error);
      throw error;
    }
  }

  async getTasksByStatus(status) {
    try {
      return await this.repository.getByStatus(status);
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ Р·Р°РґР°С‡ РїРѕ СЃС‚Р°С‚СѓСЃСѓ:', error);
      throw error;
    }
  }

  async getOverdueTasks() {
    try {
      const now = new Date().toISOString();
      return await this.repository.search({
        status: { neq: taskStatus.COMPLETED },
        due_date: { lt: now }
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РїСЂРѕСЃСЂРѕС‡РµРЅРЅС‹С… Р·Р°РґР°С‡:', error);
      throw error;
    }
  }

  subscribeToTasks(callback) {
    return this.repository.onChanges((payload) => {
      callback(payload);
    });
  }

  async getTaskStats() {
    try {
      const allTasks = await this.repository.getAll();
      
      return {
        total: allTasks.length,
        new: allTasks.filter(t => t.status === taskStatus.NEW).length,
        inProgress: allTasks.filter(t => t.status === taskStatus.IN_PROGRESS).length,
        completed: allTasks.filter(t => t.status === taskStatus.COMPLETED).length,
        overdue: (await this.getOverdueTasks()).length
      };
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ СЃС‚Р°С‚РёСЃС‚РёРєРё:', error);
      return null;
    }
  }
}

export class TaskAVRService {
  constructor() {
    this.repository = repositories.tasksAvr;
  }

  async getAll() {
    return await this.repository.getAll();
  }

  async getById(id) {
    return await this.repository.getById(id);
  }

  async create(taskData) {
    const currentUser = authService.getCurrentUser();
    
    if (!authService.canCreateTasks()) {
      throw new Error('РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ');
    }

    return await this.repository.create({
      ...taskData,
      created_by: currentUser.id,
      status: taskStatus.NEW
    });
  }

  async updateStatus(taskId, status) {
    return await this.repository.update(taskId, {
      status,
      updated_at: new Date().toISOString()
    });
  }
}

export const taskService = new TaskService();
export const taskAVRService = new TaskAVRService();

if (typeof window !== 'undefined') {
  window.taskService = taskService;
  window.taskAVRService = taskAVRService;
}
