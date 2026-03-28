/**
 * Управление монтажами
 */

import { repositories } from './api.js';
import { authService } from './auth.js';
import { APP_CONFIG } from './config.js';

const { installationStatus } = APP_CONFIG;

/**
 * Сервис управления монтажами
 */
export class InstallationService {
  constructor() {
    this.repository = repositories.installations;
  }

  /**
   * Получение всех монтажей
   */
  async getInstallations(filters = {}) {
    try {
      return await this.repository.search(filters, {
        sortBy: { field: 'created_at', ascending: false }
      });
    } catch (error) {
      console.error('Ошибка получения монтажей:', error);
      throw error;
    }
  }

  /**
   * Получение монтажа по ID
   */
  async getInstallation(installationId) {
    try {
      return await this.repository.getById(installationId);
    } catch (error) {
      console.error('Ошибка получения монтажа:', error);
      throw error;
    }
  }

  /**
   * Создание нового монтажа
   */
  async createInstallation(installationData) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('Пользователь не авторизован');
      }

      // Проверка прав
      if (!authService.hasRole([APP_CONFIG.roles.ENGINEER, APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN])) {
        throw new Error('Недостаточно прав для создания монтажа');
      }

      const installation = {
        ...installationData,
        created_by: currentUser.id,
        status: installationStatus.NEW,
        is_archived: false,
        created_at: new Date().toISOString()
      };

      return await this.repository.create(installation);
    } catch (error) {
      console.error('Ошибка создания монтажа:', error);
      throw error;
    }
  }

  /**
   * Обновление монтажа
   */
  async updateInstallation(installationId, updates) {
    try {
      const installation = await this.getInstallation(installationId);
      
      if (!installation) {
        throw new Error('Монтаж не найден');
      }

      const currentUser = authService.getCurrentUser();
      
      // Проверка прав
      const canEdit = 
        installation.created_by === currentUser?.id ||
        installation.assignee_id === currentUser?.id ||
        authService.hasRole([APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN]);

      if (!canEdit) {
        throw new Error('Недостаточно прав для редактирования');
      }

      return await this.repository.update(installationId, {
        ...updates,
        updated_at: new Date().toISOString()
      });
    } catch (error) {
      console.error('Ошибка обновления монтажа:', error);
      throw error;
    }
  }

  /**
   * Удаление монтажа
   */
  async deleteInstallation(installationId) {
    try {
      if (!authService.hasRole([APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN])) {
        throw new Error('Недостаточно прав для удаления монтажей');
      }

      return await this.repository.delete(installationId);
    } catch (error) {
      console.error('Ошибка удаления монтажа:', error);
      throw error;
    }
  }

  /**
   * Изменение статуса монтажа
   */
  async updateInstallationStatus(installationId, newStatus) {
    try {
      const updates = { 
        status: newStatus,
        updated_at: new Date().toISOString()
      };
      
      if (newStatus === installationStatus.COMPLETED) {
        updates.actual_completion_date = new Date().toISOString();
      }
      
      return await this.repository.update(installationId, updates);
    } catch (error) {
      console.error('Ошибка изменения статуса:', error);
      throw error;
    }
  }

  /**
   * Получение монтажей по статусу
   */
  async getInstallationsByStatus(status) {
    try {
      return await this.repository.search({ status });
    } catch (error) {
      console.error('Ошибка получения монтажей по статусу:', error);
      throw error;
    }
  }

  /**
   * Получение монтажей по проекту
   */
  async getInstallationsByProject(projectId) {
    try {
      return await this.repository.search({ project_id: projectId });
    } catch (error) {
      console.error('Ошибка получения монтажей проекта:', error);
      throw error;
    }
  }

  /**
   * Получение монтажей исполнителя
   */
  async getInstallationsByAssignee(assigneeId) {
    try {
      return await this.repository.search({ assignee_id: assigneeId });
    } catch (error) {
      console.error('Ошибка получения монтажей исполнителя:', error);
      throw error;
    }
  }

  /**
   * Назначение ответственного за монтаж
   */
  async assignInstallation(installationId, assigneeId) {
    try {
      return await this.updateInstallation(installationId, {
        assignee_id: assigneeId
      });
    } catch (error) {
      console.error('Ошибка назначения ответственного:', error);
      throw error;
    }
  }

  /**
   * Подписка на изменения монтажей (Realtime)
   */
  subscribeToInstallations(callback) {
    return this.repository.onChanges((payload) => {
      callback(payload);
    });
  }

  /**
   * Статистика по монтажам
   */
  async getInstallationStats() {
    try {
      const allInstallations = await this.getInstallations();
      
      return {
        total: allInstallations.length,
        new: allInstallations.filter(i => i.status === installationStatus.NEW).length,
        inProgress: allInstallations.filter(i => i.status === installationStatus.IN_PROGRESS).length,
        completed: allInstallations.filter(i => i.status === installationStatus.COMPLETED).length,
        archived: allInstallations.filter(i => i.is_archived).length
      };
    } catch (error) {
      console.error('Ошибка получения статистики:', error);
      return null;
    }
  }

  /**
   * Получение оборудования монтажа (7 СК)
   */
  getEquipmentList(installation) {
    const equipment = [];
    
    for (let i = 0; i <= 6; i++) {
      const skId = installation[`id_sk${i === 0 ? '' : i}`];
      const skName = installation[`naimenovanie_sk${i === 0 ? '' : i}`];
      const status = installation[`status_oborudovaniya${i === 0 ? '' : i}`];
      const type = installation[`tip_sk_po_dogovoru${i === 0 ? '' : i}`];
      
      if (skId || skName) {
        equipment.push({
          index: i,
          id: skId,
          name: skName,
          status,
          type
        });
      }
    }
    
    return equipment;
  }

  /**
   * Обновление оборудования монтажа
   */
  async updateEquipment(installationId, index, equipmentData) {
    try {
      const suffix = index === 0 ? '' : index;
      const updates = {};
      
      if (equipmentData.id !== undefined) {
        updates[`id_sk${suffix}`] = equipmentData.id;
      }
      if (equipmentData.name !== undefined) {
        updates[`naimenovanie_sk${suffix}`] = equipmentData.name;
      }
      if (equipmentData.status !== undefined) {
        updates[`status_oborudovaniya${suffix}`] = equipmentData.status;
      }
      if (equipmentData.type !== undefined) {
        updates[`tip_sk_po_dogovoru${suffix}`] = equipmentData.type;
      }

      return await this.updateInstallation(installationId, updates);
    } catch (error) {
      console.error('Ошибка обновления оборудования:', error);
      throw error;
    }
  }
}

// Экспорт экземпляра
export const installationService = new InstallationService();

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.installationService = installationService;
}
