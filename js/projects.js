
import { repositories } from './api.js';
import { authService } from './auth.js';
import { APP_CONFIG } from './config.js';

export class ProjectService {
  constructor() {
    this.repository = repositories.projects;
    this.tasksRepository = repositories.tasks;
  }

  async getProjects() {
    try {
      return await this.repository.getAll({
        sortBy: { field: 'created_at', ascending: false }
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РїСЂРѕРµРєС‚РѕРІ:', error);
      throw error;
    }
  }

  async getProject(projectId) {
    try {
      return await this.repository.getById(projectId);
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РїСЂРѕРµРєС‚Р°:', error);
      throw error;
    }
  }

  async createProject(projectData) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      }

      if (!authService.hasRole([APP_CONFIG.roles.ENGINEER, APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN])) {
        throw new Error('РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ РґР»СЏ СЃРѕР·РґР°РЅРёСЏ РїСЂРѕРµРєС‚Р°');
      }

      return await this.repository.create({
        ...projectData,
        created_at: new Date().toISOString()
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° СЃРѕР·РґР°РЅРёСЏ РїСЂРѕРµРєС‚Р°:', error);
      throw error;
    }
  }

  async updateProject(projectId, updates) {
    try {
      return await this.repository.update(projectId, {
        ...updates,
        updated_at: new Date().toISOString()
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° РѕР±РЅРѕРІР»РµРЅРёСЏ РїСЂРѕРµРєС‚Р°:', error);
      throw error;
    }
  }

  async deleteProject(projectId) {
    try {
      const tasks = await this.tasksRepository.search({ project_id: projectId });
      
      if (tasks && tasks.length > 0) {
        throw new Error('РќРµР»СЊР·СЏ СѓРґР°Р»РёС‚СЊ РїСЂРѕРµРєС‚ СЃ Р°РєС‚РёРІРЅС‹РјРё Р·Р°РґР°С‡Р°РјРё');
      }

      return await this.repository.delete(projectId);
    } catch (error) {
      console.error('РћС€РёР±РєР° СѓРґР°Р»РµРЅРёСЏ РїСЂРѕРµРєС‚Р°:', error);
      throw error;
    }
  }

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
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РїСЂРѕРµРєС‚Р° СЃ Р·Р°РґР°С‡Р°РјРё:', error);
      throw error;
    }
  }

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
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РїСЂРѕРµРєС‚РѕРІ СЃРѕ СЃС‚Р°С‚РёСЃС‚РёРєРѕР№:', error);
      throw error;
    }
  }

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

export const projectService = new ProjectService();

if (typeof window !== 'undefined') {
  window.projectService = projectService;
}
