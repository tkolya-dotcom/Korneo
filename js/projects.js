/**
 * Управление проектами
 */

import { repositories } from './api.js';
import { authService } from './auth.js';
import { APP_CONFIG } from './config.js';

/**
 * Сервис управления проектами
 */
export class ProjectService {
  constructor() {
    this.repository = repositories.projects;
    this.tasksRepository = repositories.tasks;
  }

  /**
   * Получение всех проектов
   */
  async getProjects() {
    try {
      return await this.repository.getAll({
        sortBy: { field: 'created_at', ascending: false }
      });
    } catch (error) {
      console.error('Ошибка получения проектов:', error);
      throw error;
    }
  }

  /**
   * Получение проекта по ID
   */
  async getProject(projectId) {
    try {
      return await this.repository.getById(projectId);
    } catch (error) {
      console.error('Ошибка получения проекта:', error);
      throw error;
    }
  }

  /**
   * Создание нового проекта
   */
  async createProject(projectData) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('Пользователь не авторизован');
      }

      // Проверка прав
      if (!authService.hasRole([APP_CONFIG.roles.ENGINEER, APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN])) {
        throw new Error('Недостаточно прав для создания проекта');
      }

      return await this.repository.create({
        ...projectData,
        created_at: new Date().toISOString()
      });
    } catch (error) {
      console.error('Ошибка создания проекта:', error);
      throw error;
    }
  }

  /**
   * Обновление проекта
   */
  async updateProject(projectId, updates) {
    try {
      return await this.repository.update(projectId, {
        ...updates,
        updated_at: new Date().toISOString()
      });
    } catch (error) {
      console.error('Ошибка обновления проекта:', error);
      throw error;
    }
  }

  /**
   * Удаление проекта
   */
  async deleteProject(projectId) {
    try {
      // Проверяем, есть ли задачи в проекте
      const tasks = await this.tasksRepository.search({ project_id: projectId });
      
      if (tasks && tasks.length > 0) {
        throw new Error('Нельзя удалить проект с активными задачами');
      }

      return await this.repository.delete(projectId);
    } catch (error) {
      console.error('Ошибка удаления проекта:', error);
      throw error;
    }
  }

  /**
   * Получение проекта с задачами
   */
  async getProjectWithTasks(projectId) {
    try {
      const [project, tasks] = await Promise.all([
        this.getProject(projectId),
        this.tasksRepository.search({ project_id: projectId })
      ]);

      return {
        project,
        tasks,
        stats: this.calculateProjectStats(tasks)
      };
    } catch (error) {
      console.error('Ошибка получения проекта с задачами:', error);
      throw error;
    }
  }

  /**
   * Подсчёт статистики проекта
   */
  calculateProjectStats(tasks) {
    const total = tasks.length;
    const completed = tasks.filter(t => t.status === APP_CONFIG.taskStatus.COMPLETED).length;
    const inProgress = tasks.filter(t => t.status === APP_CONFIG.taskStatus.IN_PROGRESS).length;
    const newTasks = tasks.filter(t => t.status === APP_CONFIG.taskStatus.NEW).length;
    
    const progress = total > 0 ? Math.round((completed / total) * 100) : 0;

    return {
      total,
      completed,
      inProgress,
      newTasks,
      progress
    };
  }

  /**
   * Получение всех проектов со статистикой
   */
  async getAllProjectsWithStats() {
    try {
      const projects = await this.getProjects();
      
      const projectsWithStats = await Promise.all(
        projects.map(async (project) => {
          const tasks = await this.tasksRepository.search({ project_id: project.id });
          const stats = this.calculateProjectStats(tasks);
          
          return {
            ...project,
            stats
          };
        })
      );

      return projectsWithStats;
    } catch (error) {
      console.error('Ошибка получения проектов со статистикой:', error);
      throw error;
    }
  }

  /**
   * Подписка на изменения проекта (Realtime)
   */
  subscribeToProject(projectId, callback) {
    return this.repository.onChanges(
      (payload) => {
        callback(payload);
      },
      {
        filter: `id=eq.${projectId}`
      }
    );
  }
}

// Экспорт экземпляра
export const projectService = new ProjectService();

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.projectService = projectService;
}
