/**
 * Вспомогательные утилиты
 */

import { APP_CONFIG } from './config.js';

/**
 * Форматирование дат
 */
export class DateUtils {
  /**
   * Форматирование в русский формат
   */
  static formatDate(date, options = {}) {
    if (!date) return '';
    
    const d = new Date(date);
    
    const defaultOptions = {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit'
    };

    return d.toLocaleDateString('ru-RU', { ...defaultOptions, ...options });
  }

  /**
   * Форматирование времени
   */
  static formatTime(date) {
    if (!date) return '';
    
    const d = new Date(date);
    return d.toLocaleTimeString('ru-RU', {
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  /**
   * Форматирование даты и времени
   */
  static formatDateTime(date) {
    return `${this.formatDate(date)} ${this.formatTime(date)}`;
  }

  /**
   * Относительное время (5 минут назад)
   */
  static relativeTime(date) {
    if (!date) return '';
    
    const now = new Date();
    const diff = now - new Date(date);
    const seconds = Math.floor(diff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (days > 0) {
      return `${days} дн. назад`;
    } else if (hours > 0) {
      return `${hours} ч. назад`;
    } else if (minutes > 0) {
      return `${minutes} мин. назад`;
    } else {
      return 'Только что';
    }
  }

  /**
   * Проверка на просроченность
   */
  static isOverdue(date) {
    if (!date) return false;
    return new Date(date) < new Date();
  }

  /**
   * Дней до дедлайна
   */
  static daysUntil(date) {
    if (!date) return null;
    
    const diff = new Date(date) - new Date();
    return Math.ceil(diff / (1000 * 60 * 60 * 24));
  }
}

/**
 * Форматирование текста
 */
export class TextUtils {
  /**
   * Обрезка текста
   */
  static truncate(text, maxLength = 100) {
    if (!text) return '';
    
    if (text.length <= maxLength) {
      return text;
    }
    
    return text.substring(0, maxLength) + '...';
  }

  /**
   * Capitalize first letter
   */
  static capitalize(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

  /**
   * Генерация инициалов
   */
  static getInitials(name) {
    if (!name) return '';
    
    const parts = name.split(' ');
    if (parts.length >= 2) {
      return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
    }
    
    return name.substring(0, 2).toUpperCase();
  }

  /**
   * Склонение слов
   */
  static declension(number, words) {
    const cases = [2, 0, 1, 1, 1, 2];
    const index = (number % 100 > 4 && number % 100 < 20) 
      ? 2 
      : cases[(number % 10 < 5) ? number % 10 : 5];
    
    return words[index];
  }

  /**
   * Форматирование номера задачи
   */
  static formatTaskNumber(num) {
    if (!num) return '';
    return `#${String(num).padStart(3, '0')}`;
  }
}

/**
 * Утилиты для статусов
 */
export class StatusUtils {
  /**
   * Получение класса статуса
   */
  static getStatusClass(status) {
    const statusMap = {
      // Задачи
      'new': 'status-new',
      'in_progress': 'status-in_progress',
      'on_hold': 'status-waiting_materials',
      'completed': 'status-done',
      'archived': 'status-postponed',
      
      // Заявки
      'pending': 'status-pending',
      'approved': 'status-approved',
      'rejected': 'status-rejected',
      'issued': 'status-received'
    };

    return statusMap[status] || 'status-draft';
  }

  /**
   * Получение текста статуса
   */
  static getStatusText(status) {
    const textMap = {
      // Задачи
      'new': 'Новая',
      'in_progress': 'В работе',
      'on_hold': 'Приостановлена',
      'completed': 'Завершена',
      'archived': 'Архив',
      
      // Заявки
      'pending': 'Ожидает',
      'approved': 'Одобрена',
      'rejected': 'Отклонена',
      'issued': 'Выдана'
    };

    return textMap[status] || status;
  }

  /**
   * Получение цвета статуса
   */
  static getStatusColor(status) {
    const colorMap = {
      'new': '#0080FF',
      'in_progress': '#00D9FF',
      'on_hold': '#FF00CC',
      'completed': '#00FF88',
      'archived': '#8892A0',
      'pending': '#FF6B00',
      'approved': '#00FF88',
      'rejected': '#FF3366',
      'issued': '#8A2BE2'
    };

    return colorMap[status] || '#8892A0';
  }
}

/**
 * Утилиты для работы с файлами
 */
export class FileUtils {
  /**
   * Проверка размера файла
   */
  static validateFileSize(file, maxSizeMB = 5) {
    const maxSizeBytes = maxSizeMB * 1024 * 1024;
    return file.size <= maxSizeBytes;
  }

  /**
   * Проверка типа файла
   */
  static validateFileType(file, allowedTypes) {
    return allowedTypes.includes(file.type);
  }

  /**
   * Форматирование размера файла
   */
  static formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + ' ' + sizes[i];
  }

  /**
   * Скачивание файла
   */
  static downloadFile(data, filename, type = 'application/json') {
    const blob = new Blob([data], { type });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    
    link.href = url;
    link.download = filename;
    link.click();
    
    URL.revokeObjectURL(url);
  }

  /**
   * Конвертация файла в Base64
   */
  static fileToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = () => resolve(reader.result);
      reader.onerror = error => reject(error);
    });
  }
}

/**
 * Утилиты для карт
 */
export class MapUtils {
  /**
   * Инициализация Mapbox
   */
  static initMapbox(container, options = {}) {
    if (!window.mapboxgl) {
      console.error('❌ Mapbox GL не загружен');
      return null;
    }

    window.mapboxgl.accessToken = window.MAPBOX_TOKEN;

    return new window.mapboxgl.Map({
      container,
      style: 'mapbox://styles/mapbox/dark-v11',
      center: [37.6173, 55.7558], // Москва
      zoom: 10,
      ...options
    });
  }

  /**
   * Построение маршрута
   */
  static async calculateRoute(coordinates) {
    try {
      const response = await fetch(
        `https://api.mapbox.com/directions/v5/mapbox/driving/${coordinates.join(';')}?access_token=${window.MAPBOX_TOKEN}&geometries=geojson`
      );
      
      const data = await response.json();
      return data.routes[0];
    } catch (error) {
      console.error('Ошибка расчёта маршрута:', error);
      return null;
    }
  }
}

/**
 * Общие утилиты
 */
export class Utils {
  /**
   * Генерация UUID
   */
  static generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0;
      const v = c === 'x' ? r : (r & 0x3 | 0x8);
      return v.toString(16);
    });
  }

  /**
   * Задержка (sleep)
   */
  static sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Глубокое копирование
   */
  static deepClone(obj) {
    return JSON.parse(JSON.stringify(obj));
  }

  /**
   * Проверка на пустоту
   */
  static isEmpty(value) {
    return value === null || value === undefined || value === '' || 
           (Array.isArray(value) && value.length === 0) ||
           (typeof value === 'object' && Object.keys(value).length === 0);
  }

  /**
   * Дебаунс
   */
  static debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  }

  /**
   * Троттл
   */
  static throttle(func, limit) {
    let inThrottle;
    return function(...args) {
      if (!inThrottle) {
        func.apply(this, args);
        inThrottle = true;
        setTimeout(() => inThrottle = false, limit);
      }
    };
  }
}

// Экспорт для совместимости с window
if (typeof window !== 'undefined') {
  window.DateUtils = DateUtils;
  window.TextUtils = TextUtils;
  window.StatusUtils = StatusUtils;
  window.FileUtils = FileUtils;
  window.MapUtils = MapUtils;
  window.Utils = Utils;
}
