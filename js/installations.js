
import { repositories } from './api.js';
import { authService } from './auth.js';
import { APP_CONFIG } from './config.js';

const { installationStatus } = APP_CONFIG;

export class InstallationService {
  constructor() {
    this.repository = repositories.installations;
  }

  async getInstallations(filters = {}) {
    try {
      return await this.repository.search(filters, {
        sortBy: { field: 'created_at', ascending: false }
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РјРѕРЅС‚Р°Р¶РµР№:', error);
      throw error;
    }
  }

  async getInstallation(installationId) {
    try {
      return await this.repository.getById(installationId);
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РјРѕРЅС‚Р°Р¶Р°:', error);
      throw error;
    }
  }

  async createInstallation(installationData) {
    try {
      const currentUser = authService.getCurrentUser();
      
      if (!currentUser) {
        throw new Error('РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ РЅРµ Р°РІС‚РѕСЂРёР·РѕРІР°РЅ');
      }

      if (!authService.hasRole([APP_CONFIG.roles.ENGINEER, APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN])) {
        throw new Error('РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ РґР»СЏ СЃРѕР·РґР°РЅРёСЏ РјРѕРЅС‚Р°Р¶Р°');
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
      console.error('РћС€РёР±РєР° СЃРѕР·РґР°РЅРёСЏ РјРѕРЅС‚Р°Р¶Р°:', error);
      throw error;
    }
  }

  async updateInstallation(installationId, updates) {
    try {
      const installation = await this.getInstallation(installationId);
      
      if (!installation) {
        throw new Error('РњРѕРЅС‚Р°Р¶ РЅРµ РЅР°Р№РґРµРЅ');
      }

      const currentUser = authService.getCurrentUser();
      
      const canEdit = 
        installation.created_by === currentUser?.id ||
        installation.assignee_id === currentUser?.id ||
        authService.hasRole([APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN]);

      if (!canEdit) {
        throw new Error('РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ РґР»СЏ СЂРµРґР°РєС‚РёСЂРѕРІР°РЅРёСЏ');
      }

      return await this.repository.update(installationId, {
        ...updates,
        updated_at: new Date().toISOString()
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° РѕР±РЅРѕРІР»РµРЅРёСЏ РјРѕРЅС‚Р°Р¶Р°:', error);
      throw error;
    }
  }

  async deleteInstallation(installationId) {
    try {
      if (!authService.hasRole([APP_CONFIG.roles.MANAGER, APP_CONFIG.roles.DEPUTY_HEAD, APP_CONFIG.roles.ADMIN])) {
        throw new Error('РќРµРґРѕСЃС‚Р°С‚РѕС‡РЅРѕ РїСЂР°РІ РґР»СЏ СѓРґР°Р»РµРЅРёСЏ РјРѕРЅС‚Р°Р¶РµР№');
      }

      return await this.repository.delete(installationId);
    } catch (error) {
      console.error('РћС€РёР±РєР° СѓРґР°Р»РµРЅРёСЏ РјРѕРЅС‚Р°Р¶Р°:', error);
      throw error;
    }
  }

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
      console.error('РћС€РёР±РєР° РёР·РјРµРЅРµРЅРёСЏ СЃС‚Р°С‚СѓСЃР°:', error);
      throw error;
    }
  }

  async getInstallationsByStatus(status) {
    try {
      return await this.repository.search({ status });
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РјРѕРЅС‚Р°Р¶РµР№ РїРѕ СЃС‚Р°С‚СѓСЃСѓ:', error);
      throw error;
    }
  }

  async getInstallationsByProject(projectId) {
    try {
      return await this.repository.search({ project_id: projectId });
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РјРѕРЅС‚Р°Р¶РµР№ РїСЂРѕРµРєС‚Р°:', error);
      throw error;
    }
  }

  async getInstallationsByAssignee(assigneeId) {
    try {
      return await this.repository.search({ assignee_id: assigneeId });
    } catch (error) {
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ РјРѕРЅС‚Р°Р¶РµР№ РёСЃРїРѕР»РЅРёС‚РµР»СЏ:', error);
      throw error;
    }
  }

  async assignInstallation(installationId, assigneeId) {
    try {
      return await this.updateInstallation(installationId, {
        assignee_id: assigneeId
      });
    } catch (error) {
      console.error('РћС€РёР±РєР° РЅР°Р·РЅР°С‡РµРЅРёСЏ РѕС‚РІРµС‚СЃС‚РІРµРЅРЅРѕРіРѕ:', error);
      throw error;
    }
  }

  subscribeToInstallations(callback) {
    return this.repository.onChanges((payload) => {
      callback(payload);
    });
  }

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
      console.error('РћС€РёР±РєР° РїРѕР»СѓС‡РµРЅРёСЏ СЃС‚Р°С‚РёСЃС‚РёРєРё:', error);
      return null;
    }
  }

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
      console.error('РћС€РёР±РєР° РѕР±РЅРѕРІР»РµРЅРёСЏ РѕР±РѕСЂСѓРґРѕРІР°РЅРёСЏ:', error);
      throw error;
    }
  }
}

export const installationService = new InstallationService();

if (typeof window !== 'undefined') {
  window.installationService = installationService;
}
