/**
 * atss-upload.js
 * ==============
 * Загрузка план-графика АТСС (.xlsx) в таблицу atss_q1_2026 через Supabase.
 *
 * Зависимости (уже подключены в index.html проекта):
 *   - @supabase/supabase-js (window.supabase)
 *   - SheetJS / xlsx (window.XLSX) — подключается в atss-upload.html
 *
 * Использование:
 *   import { atssUploadService } from './js/atss-upload.js';
 *   atssUploadService.initUI('atss-upload-container');
 */

import { SUPABASE_CONFIG, APP_CONFIG } from './config.js';
import { getSupabase } from './api.js';
import { authService } from './auth.js';

// ── Константы ────────────────────────────────────────────────────────────────

const TABLE      = 'atss_q1_2026';
const SHEET_NAME = '1 квартал 2026';
const BATCH_SIZE = 50;

// Роли, которым разрешена загрузка
const ALLOWED_ROLES = [
  APP_CONFIG.roles.ADMIN,
  APP_CONFIG.roles.MANAGER,
  APP_CONFIG.roles.DEPUTY_HEAD,
];

// ── Вспомогательные функции ──────────────────────────────────────────────────

function safeInt(v) {
  if (v === null || v === undefined || v === '') return null;
  const n = parseInt(v, 10);
  return isNaN(n) ? null : n;
}

function safeStr(v) {
  if (v === null || v === undefined) return null;
  const s = String(v).trim();
  return s === '' || s === '-' ? null : s;
}

function fmtDate(v) {
  if (!v) return null;
  if (v instanceof Date) {
    const y = v.getFullYear();
    const m = String(v.getMonth() + 1).padStart(2, '0');
    const d = String(v.getDate()).padStart(2, '0');
    return parseInt(`${y}${m}${d}`, 10);
  }
  const n = parseInt(String(v).replace(/\D/g, ''), 10);
  return isNaN(n) ? null : n;
}

// ── Парсинг XLSX ──────────────────────────────────────────────────────────────

/**
 * Читает ArrayBuffer xlsx-файла, возвращает массив плоских объектов
 * готовых для upsert в Supabase.
 */
function parseXlsx(arrayBuffer) {
  if (!window.XLSX) throw new Error('Библиотека XLSX не загружена');

  const wb = window.XLSX.read(arrayBuffer, { type: 'array', cellDates: true });
  const ws = wb.Sheets[SHEET_NAME];

  if (!ws) {
    const available = wb.SheetNames.join(', ');
    throw new Error(`Лист "${SHEET_NAME}" не найден. Доступные: ${available}`);
  }

  const rows = window.XLSX.utils.sheet_to_json(ws, {
    header: 1,
    defval: null,
    raw: false,
  });

  // Группируем строки по площадке (servisnyy_id + id_ploshadki)
  const groups = new Map();

  for (let ri = 1; ri < rows.length; ri++) {
    const row = rows[ri];
    if (!row) continue;

    const [tip, id_pl, serv, adres, rayon, id_sk, naim, status, tip_sk, plan] = row;

    if (tip == null && id_pl == null && serv == null) continue;

    const key = `${serv}__${id_pl}`;

    if (!groups.has(key)) {
      groups.set(key, {
        tip:                  safeStr(tip),
        id_ploshadki:         safeInt(id_pl),
        servisnyy_id:         safeStr(serv),
        adres_razmeshcheniya: safeStr(adres),
        rayon:                safeStr(rayon),
        plan_date:            null,
        sks:                  [],
      });
    }

    const g = groups.get(key);
    if (plan && g.plan_date === null) g.plan_date = plan;

    g.sks.push({
      id_sk:   safeInt(id_sk),
      naim:    safeStr(naim),
      status:  safeStr(status),
      tip_sk:  safeInt(tip_sk),
    });
  }

  // Разворачиваем в плоские объекты для upsert
  return [...groups.values()].map(g => {
    const rec = {
      tip:                  g.tip,
      id_ploshadki:         g.id_ploshadki,
      servisnyy_id:         g.servisnyy_id,
      adres_razmeshcheniya: g.adres_razmeshcheniya,
      rayon:                g.rayon,
      planovaya_data_1_kv_2026: fmtDate(g.plan_date),
      // СК 1 (без цифры — как в реальной таблице)
      id_sk: null, naimenovanie_sk: null, status_oborudovaniya: null, tip_sk_po_dogovoru: null,
      // СК 2–6
      id_sk2: null, naimenovanie_sk2: null, status_oborudovaniya2: null, tip_sk_po_dogovoru2: null,
      id_sk3: null, naimenovanie_sk3: null, status_oborudovaniya3: null, tip_sk_po_dogovoru3: null,
      id_sk4: null, naimenovanie_sk4: null, status_oborudovaniya4: null, tip_sk_po_dogovoru4: null,
      id_sk5: null, naimenovanie_sk5: null, status_oborudovaniya5: null, tip_sk_po_dogovoru5: null,
      id_sk6: null, naimenovanie_sk6: null, status_oborudovaniya6: null, tip_sk_po_dogovoru6: null,
    };

    g.sks.forEach((sk, idx) => {
      const sfx = idx === 0 ? '' : String(idx + 1);
      rec[`id_sk${sfx}`]               = sk.id_sk;
      rec[`naimenovanie_sk${sfx}`]      = sk.naim;
      rec[`status_oborudovaniya${sfx}`] = sk.status;
      rec[`tip_sk_po_dogovoru${sfx}`]   = sk.tip_sk;
    });

    return rec;
  });
}

// ── Upsert в Supabase ─────────────────────────────────────────────────────────

/**
 * Отправляет записи батчами.
 * @param {Array} records
 * @param {Function} onProgress (done, total, errCount)
 * @returns {Array} массив ошибок [{from, to, message}]
 */
async function upsertBatches(records, onProgress) {
  const client = getSupabase();
  const total  = records.length;
  let done = 0;
  const errors = [];

  for (let i = 0; i < total; i += BATCH_SIZE) {
    const batch = records.slice(i, i + BATCH_SIZE);

    const { error } = await client
      .from(TABLE)
      .upsert(batch, {
        onConflict:       'id_ploshadki',
        ignoreDuplicates: false,           // false = обновлять при изменении
      });

    if (error) {
      errors.push({ from: i, to: i + batch.length, message: error.message });
    }

    done += batch.length;
    onProgress(done, total, errors.length);
  }

  return errors;
}

// ── UI ────────────────────────────────────────────────────────────────────────

const CSS = `
  .atss-uploader {
    background: #16161e;
    border: 1px solid #2a2a3e;
    border-radius: 12px;
    padding: 24px;
    max-width: 560px;
    font-family: system-ui, -apple-system, sans-serif;
    color: #e0e0e0;
  }
  .atss-uploader h3 {
    margin: 0 0 20px;
    font-size: 15px;
    font-weight: 600;
    color: #fff;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .atss-field { margin-bottom: 14px; }
  .atss-field label {
    display: block;
    font-size: 12px;
    color: #888;
    margin-bottom: 6px;
    text-transform: uppercase;
    letter-spacing: .5px;
  }
  .atss-field input[type="file"] {
    width: 100%;
    box-sizing: border-box;
    padding: 10px 12px;
    background: #0d0d18;
    border: 1px dashed #3a3a5e;
    border-radius: 8px;
    color: #ccc;
    font-size: 13px;
    cursor: pointer;
  }
  .atss-field input[type="file"]:hover { border-color: #5a7ef5; }
  .atss-btn {
    width: 100%;
    padding: 11px;
    background: #5a7ef5;
    color: #fff;
    border: none;
    border-radius: 8px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: background .2s, opacity .2s;
    margin-top: 4px;
  }
  .atss-btn:hover:not(:disabled) { background: #4060d4; }
  .atss-btn:disabled { opacity: .5; cursor: default; }
  .atss-progress { margin-top: 18px; display: none; }
  .atss-bar-bg {
    background: #1e1e30;
    border-radius: 4px;
    height: 6px;
    overflow: hidden;
  }
  .atss-bar {
    height: 100%;
    background: #5a7ef5;
    width: 0;
    transition: width .3s ease;
    border-radius: 4px;
  }
  .atss-bar.success { background: #27ae60; }
  .atss-bar.error   { background: #e74c3c; }
  .atss-status {
    font-size: 12px;
    color: #aaa;
    margin-top: 6px;
  }
  .atss-log {
    margin-top: 14px;
    background: #0d0d18;
    border: 1px solid #2a2a3e;
    border-radius: 8px;
    padding: 10px 12px;
    font-size: 12px;
    font-family: 'Courier New', monospace;
    max-height: 180px;
    overflow-y: auto;
    display: none;
    line-height: 1.7;
  }
  .atss-log .ok   { color: #27ae60; }
  .atss-log .err  { color: #e74c3c; }
  .atss-log .inf  { color: #aaa; }
  .atss-no-access {
    color: #e74c3c;
    font-size: 13px;
    padding: 12px;
    background: rgba(231,76,60,.1);
    border-radius: 8px;
    text-align: center;
  }
`;

function buildUI(el) {
  // Вставляем стили один раз
  if (!document.getElementById('atss-upload-style')) {
    const style = document.createElement('style');
    style.id = 'atss-upload-style';
    style.textContent = CSS;
    document.head.appendChild(style);
  }

  el.innerHTML = `
    <div class="atss-uploader">
      <h3>📋 Загрузка план-графика АТСС</h3>
      <div class="atss-field">
        <label>Файл Excel (.xlsx)</label>
        <input id="atss-file-input" type="file" accept=".xlsx,.xls"/>
      </div>
      <button id="atss-upload-btn" class="atss-btn">⬆ Загрузить в базу</button>
      <div class="atss-progress" id="atss-progress">
        <div class="atss-bar-bg">
          <div class="atss-bar" id="atss-bar"></div>
        </div>
        <div class="atss-status" id="atss-status"></div>
      </div>
      <div class="atss-log" id="atss-log"></div>
    </div>
  `;

  const btn      = el.querySelector('#atss-upload-btn');
  const fileInp  = el.querySelector('#atss-file-input');
  const progress = el.querySelector('#atss-progress');
  const bar      = el.querySelector('#atss-bar');
  const status   = el.querySelector('#atss-status');
  const log      = el.querySelector('#atss-log');

  function addLog(msg, type = 'inf') {
    log.style.display = 'block';
    const line = document.createElement('div');
    line.className = type;
    line.textContent = msg;
    log.appendChild(line);
    log.scrollTop = log.scrollHeight;
  }

  btn.addEventListener('click', async () => {
    const file = fileInp?.files?.[0];
    if (!file) { addLog('⚠ Выберите файл .xlsx', 'err'); return; }

    btn.disabled = true;
    log.innerHTML = '';
    log.style.display = 'block';
    progress.style.display = 'block';
    bar.className = 'atss-bar';
    bar.style.width = '0%';

    try {
      // 1. Парсим файл
      addLog(`📂 Читаем: ${file.name}`);
      status.textContent = 'Разбираем файл…';

      const buffer  = await file.arrayBuffer();
      const records = parseXlsx(buffer);

      addLog(`✓ Площадок найдено: ${records.length}`, 'ok');
      addLog(`⬆ Отправляем в Supabase батчами по ${BATCH_SIZE}…`);

      // 2. Upsert
      const errors = await upsertBatches(records, (done, total, errCnt) => {
        const pct = Math.round((done / total) * 100);
        bar.style.width = pct + '%';
        status.textContent = `${done} / ${total} записей · ошибок: ${errCnt}`;
      });

      // 3. Итог
      if (errors.length === 0) {
        bar.classList.add('success');
        addLog(`✅ Готово! Загружено ${records.length} записей`, 'ok');
        status.textContent = `✅ Успешно загружено ${records.length} записей`;
      } else {
        bar.classList.add('error');
        addLog(`⚠ Завершено с ${errors.length} ошибками:`, 'err');
        errors.forEach(e => addLog(`  строки ${e.from}–${e.to}: ${e.message}`, 'err'));
        status.textContent = `⚠ Завершено с ошибками (${errors.length})`;
      }

    } catch (err) {
      bar.classList.add('error');
      addLog(`❌ ${err.message}`, 'err');
      status.textContent = '❌ Ошибка';
    } finally {
      btn.disabled = false;
    }
  });
}

// ── Публичный API ─────────────────────────────────────────────────────────────

export const atssUploadService = {

  /**
   * Инициализирует UI загрузчика в указанном контейнере.
   * Показывает форму только если у пользователя есть нужная роль.
   *
   * @param {string} containerId — id HTML-элемента
   */
  initUI(containerId) {
    const el = document.getElementById(containerId);
    if (!el) {
      console.error(`atss-upload: элемент #${containerId} не найден`);
      return;
    }

    // Проверка роли
    const userRole = localStorage.getItem('user_role') || '';
    if (!ALLOWED_ROLES.includes(userRole)) {
      el.innerHTML = `
        <div class="atss-uploader">
          <div class="atss-no-access">
            🔒 Загрузка доступна только менеджерам и администраторам
          </div>
        </div>
      `;
      return;
    }

    buildUI(el);
  },

  /**
   * Только парсинг xlsx без UI — возвращает массив записей.
   * Можно использовать для предпросмотра данных перед отправкой.
   *
   * @param {File} file
   * @returns {Promise<Array>}
   */
  async parseFile(file) {
    const buffer = await file.arrayBuffer();
    return parseXlsx(buffer);
  },

  /**
   * Только отправка — если нужно самому управлять прогрессом.
   *
   * @param {Array} records
   * @param {Function} onProgress
   * @returns {Promise<Array>} ошибки
   */
  async upload(records, onProgress = () => {}) {
    return upsertBatches(records, onProgress);
  },
};
