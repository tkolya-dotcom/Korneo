/**
 * Управление задачами
 * Бизнес-логика для работы с задачами
 */

import { repositories } from './api.js';
import { authService } from './auth.js';
import { APP_CONFIG } from './config.js';

const { taskStatus, priorities } = APP_CONFIG;

/**
 * Сервис управления задачами
 */
export class TaskService {
  constructor() {
    this.repository = repositories.tasks;
  }

  /**
   * Получение всех задач с фильтрами
   */
  async getTasks(filters = {}) {
    try {
      return await this.repository.search(filters, {
        sortBy: { field: 'created_at', ascending: false }
      });
    } catch (error) {
      console.error('Ошибка получения задач:', error);
      throw error;
    }
  }

  /**
   * Получение задач пользователя
   */
  async getUserTasks(userId) {
    try {
      return await this.repository.getByAssignee(userId);
    } catch (error) {
      console.error('Ошибка получения задач пользователя:', error);
      throw error;
    }
  }

  /**
   * Получение задачи по ID
   */
  async getTask(taskId) {
    try {
      return await this.repository.getById(taskId);
    } catch (error) {
      console.error('Ошибка получения задачи:', error);
      throw error;
    }
  }

  /**
   * Создание новой задачи
   */
  async createTask(taskData) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('Пользователь не авторизован');
      }

      // Проверка прав
      if (!authService.canCreateTasks()) {
        throw new Error('Недостаточно прав для создания задач');
      }

      const task = {
        ...taskData,
        created_by: currentUser.id,
        status: taskStatus.NEW,
        is_archived: false
      };

      return await this.repository.create(task);
    } catch (error) {
      console.error('Ошибка создания задачи:', error);
      throw error;
    }
  }

  /**
   * Обновление задачи
   */
  async updateTask(taskId, updates) {
    try {
      const task = await this.getTask(taskId);
      
      if (!task) {
        throw new Error('Задача не найдена');
      }

      const currentUser = authService.getCurrentUser();
      
      // Проверка прав
      const canEdit = 
        task.created_by === currentUser?.id ||
        task.assignee_id === currentUser?.id ||
        authService.hasRole([APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN]);

      if (!canEdit) {
        throw new Error('Недостаточно прав для редактирования');
      }

      return await this.repository.update(taskId, {
        ...updates,
        updated_at: new Date().toISOString()
      });
    } catch (error) {
      console.error('Ошибка обновления задачи:', error);
      throw error;
    }
  }

  /**
   * Удаление задачи
   */
  async deleteTask(taskId) {
    try {
      if (!authService.canDeleteTasks()) {
        throw new Error('Недостаточно прав для удаления задач');
      }

      return await this.repository.delete(taskId);
    } catch (error) {
      console.error('Ошибка удаления задачи:', error);
      throw error;
    }
  }

  /**
   * Изменение статуса задачи
   */
  async updateTaskStatus(taskId, newStatus) {
    try {
      return await this.repository.updateStatus(taskId, newStatus);
    } catch (error) {
      console.error('Ошибка изменения статуса:', error);
      throw error;
    }
  }

  /**
   * Назначение исполнителя
   */
  async assignTask(taskId, assigneeId) {
    try {
      return await this.updateTask(taskId, {
        assignee_id: assigneeId
      });
    } catch (error) {
      console.error('Ошибка назначения исполнителя:', error);
      throw error;
    }
  }

  /**
   * Получение задач по статусу
   */
  async getTasksByStatus(status) {
    try {
      return await this.repository.getByStatus(status);
    } catch (error) {
      console.error('Ошибка получения задач по статусу:', error);
      throw error;
    }
  }

  /**
   * Получение просроченных задач
   */
  async getOverdueTasks() {
    try {
      const now = new Date().toISOString();
      return await this.repository.search({
        status: { neq: taskStatus.COMPLETED },
        due_date: { lt: now }
      });
    } catch (error) {
      console.error('Ошибка получения просроченных задач:', error);
      throw error;
    }
  }

  /**
   * Подписка на изменения задач (Realtime)
   */
  subscribeToTasks(callback) {
    return this.repository.onChanges((payload) => {
      callback(payload);
    });
  }

  /**
   * Статистика по задачам
   */
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
      console.error('Ошибка получения статистики:', error);
      return null;
    }
  }
}

/**
 * Сервис задач АВР (Аварийно-Восстановительные Работы)
 */
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
      throw new Error('Недостаточно прав');
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

// Экспорт экземпляров
export const taskService = new TaskService();
export const taskAVRService = new TaskAVRService();

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.taskService = taskService;
  window.taskAVRService = taskAVRService;
}
