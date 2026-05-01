/**
 * Edge Function: sync-sites
 *
 * Синхронизирует данные площадок с bi.sats.spb.ru → Supabase.
 * Обрабатывает только площадки, у которых id_ploshadki заполнен в таблице installations.
 *
 * Запрос: POST /functions/v1/sync-sites
 * Body (опционально): { "site_ids": [196621538, ...] }  — конкретные ID, иначе все из installations
 *
 * Авторизация: Bearer <SUPABASE_SERVICE_ROLE_KEY>  или  x-sync-secret: <SYNC_SECRET>
 */

import { createClient } from "jsr:@supabase/supabase-js@2";

// ── Конфигурация ─────────────────────────────────────────────────────────────
const SATS_BASE    = "https://bi.sats.spb.ru/suremts";
const SATS_USER    = Deno.env.get("SATS_USERNAME") ?? "dispatcher";
const SATS_PASS    = Deno.env.get("SATS_PASSWORD") ?? "";
const SYNC_SECRET  = Deno.env.get("SYNC_SECRET")   ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")  ?? "";
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Категории устройств по типу (ключевые слова в нижнем регистре)
const CATEGORY_MAP: Record<string, string> = {
  "коммутатор": "switch",
  "маршрутизатор": "switch",
  "switch": "switch",
  "router": "switch",
  "ибп": "ups",
  "ups": "ups",
  "источник бесперебойного": "ups",
  "кондиционер": "ac",
  "сплит": "ac",
  "mitsubishi": "ac",
  "daikin": "ac",
  "haier": "ac",
};

function detectCategory(typeStr: string, modelStr: string): string {
  const hay = `${typeStr} ${modelStr}`.toLowerCase();
  for (const [kw, cat] of Object.entries(CATEGORY_MAP)) {
    if (hay.includes(kw)) return cat;
  }
  return "other";
}

// ── APEX-сессия ──────────────────────────────────────────────────────────────
let apexSession: string | null = null;

async function getApexSession(): Promise<string> {
  if (apexSession) return apexSession;

  // Шаг 1: загружаем главную страницу — получаем session в URL редиректа
  const homeResp = await fetch(`${SATS_BASE}/f?p=101`, { redirect: "follow" });
  const homeUrl  = homeResp.url; // f?p=101:5:SESSION::NO:RP::
  const match    = homeUrl.match(/f\?p=101:\d+:(\d+)/);
  if (!match) throw new Error(`Не удалось получить APEX-сессию из URL: ${homeUrl}`);

  apexSession = match[1];

  // Шаг 2: если нужна авторизация — логинимся
  // (сессия dispatcher обычно уже авторизована через IP/сессию)
  if (SATS_PASS) {
    await fetch(`${SATS_BASE}/wwv_flow.accept`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        p_flow_id:   "101",
        p_flow_step_id: "101",
        p_instance:  apexSession,
        p_arg_names: "P101_USERNAME,P101_PASSWORD",
        p_arg_values: `${SATS_USER},${SATS_PASS}`,
      }),
    });
  }

  return apexSession;
}

// ── Получение данных площадки (страница 8) ───────────────────────────────────
async function fetchSiteDetail(siteId: number): Promise<Record<string, string>> {
  const session = await getApexSession();
  const url     = `${SATS_BASE}/f?p=101:8:${session}::NO:RP:P8_ID:${siteId}`;
  const resp    = await fetch(url);
  const html    = await resp.text();

  // Парсим поля через регулярки (Oracle APEX рендерит dl/dt/dd)
  const extract = (label: string): string => {
    // Ищем: <dt>...LABEL...</dt>\s*<dd>VALUE</dd>
    const re = new RegExp(
      `<dt[^>]*>[^<]*${escapeRe(label)}[^<]*<\\/dt>\\s*<dd[^>]*>([\\s\\S]*?)<\\/dd>`,
      "i"
    );
    const m = html.match(re);
    if (!m) return "";
    return m[1].replace(/<[^>]+>/g, "").trim();
  };

  // Контакты: секция "Контакты" → список телефон + имя
  const contacts: Array<{ phone: string; name: string }> = [];
  const contactSection = html.match(/Контакты:?([\s\S]*?)(?:Расположение шкафов|<\/div>)/i)?.[1] ?? "";
  const phoneRe = /(\+?[\d\s\-]{10,})\s*[—–-]\s*([^<\n]+)/g;
  let pm: RegExpExecArray | null;
  while ((pm = phoneRe.exec(contactSection)) !== null) {
    contacts.push({ phone: pm[1].trim(), name: pm[2].trim() });
  }

  // Шкафы: секция "Расположение шкафов"
  const cabinets: Array<{ name: string; floor: string; room: string }> = [];
  const cabSection = html.match(/Расположение шкафов:?([\s\S]*?)(?:<\/div>|Оборудование)/i)?.[1] ?? "";
  // Каждая строка: имя_шкафа → Этаж: N. Помещение: X.
  const cabRe = /([ТШ\w\s№]+?)\s*(?:→|Этаж).*?Этаж:\s*(\d+)[.\s]+Помещение:\s*([^<.\n]+)/gi;
  let cm: RegExpExecArray | null;
  while ((cm = cabRe.exec(cabSection)) !== null) {
    cabinets.push({ name: cm[1].trim(), floor: cm[2].trim(), room: cm[3].trim() });
  }

  return {
    type:            extract("Тип"),
    segment:         extract("Сегмент"),
    status:          extract("Статус"),
    district:        extract("Район"),
    address:         extract("Адрес"),
    connection_type: extract("Тип подключения"),
    commissioned_at: extract("Дата ввода в эксплуатацию"),
    description:     extract("Описание"),
    _contacts:       JSON.stringify(contacts),
    _cabinets:       JSON.stringify(cabinets),
  };
}

// ── Получение оборудования площадки ─────────────────────────────────────────
async function fetchSiteEquipment(siteId: number): Promise<EquipItem[]> {
  const session = await getApexSession();

  // Страница 8 вкладка Оборудование
  const url  = `${SATS_BASE}/f?p=101:8:${session}::NO:RP:P8_ID:${siteId}`;
  const resp = await fetch(url);
  const html = await resp.text();

  // Извлекаем ссылки на карточки оборудования: /f?p=101:22:SESSION::NO:RP:P22_ID:XXXXX
  // Также стр.47 (UPS), стр.34 (шкаф), стр.56 (прочее)
  const equipPageRe = /f\?p=101:(22|47|56|34):[\d]+::NO:RP:P(?:22|47|56|34)_ID:(\d+)/g;
  const found = new Map<string, { page: string; equipId: string }>();
  let m: RegExpExecArray | null;
  while ((m = equipPageRe.exec(html)) !== null) {
    const key = `${m[1]}_${m[2]}`;
    if (!found.has(key)) found.set(key, { page: m[1], equipId: m[2] });
  }

  // Для каждого устройства получаем карточку
  const items: EquipItem[] = [];
  const promises = [...found.values()].map(async ({ page, equipId }) => {
    try {
      const item = await fetchEquipCard(page, equipId, session);
      if (item) items.push(item);
    } catch {
      // пропускаем ошибочные карточки
    }
  });

  // Параллельно, но не более 5 одновременно
  await Promise.allSettled(promises);
  return items;
}

interface EquipItem {
  emts_equip_id:   number;
  name:            string;
  model:           string;
  manufacturer:    string;
  device_type:     string;
  device_category: string;
  cabinet:         string;
  status:          string;
  serial_number:   string;
  inventory_number:string;
  power_watts:     number | null;
  power_va:        number | null;
}

async function fetchEquipCard(page: string, equipId: string, session: string): Promise<EquipItem | null> {
  const paramMap: Record<string, string> = { "22": "P22_ID", "47": "P47_ID", "56": "P56_ID", "34": "P34_ID" };
  const param = paramMap[page];
  if (!param) return null;

  const url  = `${SATS_BASE}/f?p=101:${page}:${session}::NO:RP:${param}:${equipId}`;
  const resp = await fetch(url);
  const html = await resp.text();

  const extract = (label: string): string => {
    const re = new RegExp(
      `<dt[^>]*>[^<]*${escapeRe(label)}[^<]*<\\/dt>\\s*<dd[^>]*>([\\s\\S]*?)<\\/dd>`,
      "i"
    );
    const m = html.match(re);
    if (!m) return "";
    return m[1].replace(/<[^>]+>/g, "").trim();
  };

  const typeStr  = extract("Тип устройства");
  const model    = extract("Модель");
  const category = detectCategory(typeStr, model);

  // Мощность: страница 22 → "Номинальная мощность,Вт"; страница 47 → "Мощность, ВА"
  let powerWatts: number | null = null;
  let powerVa:    number | null = null;

  if (page === "22") {
    const raw = extract("Номинальная мощность");
    const val = parseFloat(raw.replace(/[^\d.]/g, ""));
    if (!isNaN(val) && val > 0) powerWatts = val;
  } else if (page === "47") {
    const raw = extract("Мощность");
    const val = parseFloat(raw.replace(/[^\d.]/g, ""));
    if (!isNaN(val) && val > 0) powerVa = val;
  }

  // Определяем имя устройства из заголовка h1 или title
  const nameMatch = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
  const name      = nameMatch ? nameMatch[1].trim() : `equip-${equipId}`;

  // Шкаф/родитель из breadcrumb: Площадки \ [EMTS...] \ ТШ №1 \ имя
  const breadcrumb = html.match(/Площадки[\s\S]*?\\([\s\S]*?)\\([^\\<]+)\\[^\\<]+$/m);
  const cabinet    = breadcrumb ? breadcrumb[2].trim() : "";

  return {
    emts_equip_id:    parseInt(equipId),
    name,
    model,
    manufacturer:     extract("Фирма изготовитель"),
    device_type:      typeStr,
    device_category:  category,
    cabinet,
    status:           extract("Статус"),
    serial_number:    extract("Серийный номер"),
    inventory_number: extract("Инвентарный номер"),
    power_watts:      powerWatts,
    power_va:         powerVa,
  };
}

// ── Утилиты ──────────────────────────────────────────────────────────────────
function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function parseDate(s: string): string | null {
  if (!s) return null;
  // DD.MM.YYYY → YYYY-MM-DD
  const m = s.match(/^(\d{2})\.(\d{2})\.(\d{4})/);
  if (m) return `${m[3]}-${m[2]}-${m[1]}`;
  return null;
}

// ── Основной обработчик ──────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  // CORS для браузерных вызовов
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Headers": "authorization, x-sync-secret, content-type",
      },
    });
  }

  // Аутентификация: service_role token или x-sync-secret
  const authHeader = req.headers.get("authorization") ?? "";
  const syncSecret = req.headers.get("x-sync-secret")  ?? "";
  const isServiceRole = authHeader.includes(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "____");
  const isSecretOk    = SYNC_SECRET && syncSecret === SYNC_SECRET;

  if (!isServiceRole && !isSecretOk) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  // Инициализируем Supabase с service_role
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Получаем список площадок для синхронизации
  let siteIds: number[] = [];

  try {
    const body = await req.json().catch(() => ({}));
    if (Array.isArray(body.site_ids) && body.site_ids.length > 0) {
      siteIds = body.site_ids.map(Number).filter(Boolean);
    }
  } catch { /* тело может быть пустым */ }

  if (siteIds.length === 0) {
    // Берём все installations с заполненным id_ploshadki
    const { data: installs } = await supabase
      .from("installations")
      .select("id_ploshadki, servisnyy_id, title")
      .not("id_ploshadki", "is", null);

    siteIds = (installs ?? [])
      .map((r: Record<string, unknown>) => parseInt(String(r.id_ploshadki)))
      .filter((id: number) => !isNaN(id) && id > 0);
  }

  if (siteIds.length === 0) {
    return new Response(JSON.stringify({ message: "Нет площадок для синхронизации" }), { status: 200 });
  }

  const results: Array<{ site_id: number; status: string; error?: string }> = [];

  for (const siteId of siteIds) {
    try {
      // 1. Получаем базовые данные площадки
      const detail = await fetchSiteDetail(siteId);

      // Парсим наименование из HTML для emts_code
      const session  = await getApexSession();
      const pageUrl  = `${SATS_BASE}/f?p=101:8:${session}::NO:RP:P8_ID:${siteId}`;
      const pageResp = await fetch(pageUrl);
      const pageHtml = await pageResp.text();

      const titleMatch = pageHtml.match(/<h1[^>]*>([^<]+)<\/h1>/i);
      const fullTitle  = titleMatch ? titleMatch[1].trim() : `Site ${siteId}`;
      const codeMatch  = fullTitle.match(/\[([^\]]+)\]/);
      const emtsCode   = codeMatch ? codeMatch[1] : null;

      // 2. Upsert в sites_cache
      const { data: siteRow, error: siteErr } = await supabase
        .from("sites_cache")
        .upsert({
          emts_id:         siteId,
          emts_code:       emtsCode,
          name:            fullTitle,
          address:         detail.address   || null,
          type:            detail.type      || null,
          segment:         detail.segment   || null,
          status:          detail.status    || null,
          district:        detail.district  || null,
          connection_type: detail.connection_type || null,
          commissioned_at: parseDate(detail.commissioned_at),
          description:     detail.description || null,
          contacts:        JSON.parse(detail._contacts  || "[]"),
          cabinets:        JSON.parse(detail._cabinets  || "[]"),
          synced_at:       new Date().toISOString(),
        }, { onConflict: "emts_id" })
        .select("id")
        .single();

      if (siteErr || !siteRow) throw new Error(siteErr?.message ?? "upsert failed");

      const dbSiteId = siteRow.id;

      // 3. Получаем оборудование
      const equipment = await fetchSiteEquipment(siteId);

      // 4. Для оборудования без мощности — запрашиваем lookup-power
      const lookupUrl = `${SUPABASE_URL}/functions/v1/lookup-power`;
      const uniqueModels = [...new Set(
        equipment
          .filter((e) => e.power_watts === null && e.power_va === null && e.model)
          .map((e) => e.model)
      )];

      // Запрашиваем мощности параллельно (не более 5 одновременно)
      const powerMap = new Map<string, { watts: number | null; va: number | null }>();
      const lookupChunks = [];
      for (let i = 0; i < uniqueModels.length; i += 5) {
        lookupChunks.push(uniqueModels.slice(i, i + 5));
      }
      for (const chunk of lookupChunks) {
        await Promise.allSettled(
          chunk.map(async (model) => {
            try {
              const equip = equipment.find((e) => e.model === model);
              const r = await fetch(lookupUrl, {
                method: "POST",
                headers: {
                  "Content-Type":  "application/json",
                  "Authorization": `Bearer ${SERVICE_KEY}`,
                },
                body: JSON.stringify({
                  model,
                  manufacturer: equip?.manufacturer ?? "",
                  device_type:  equip?.device_type  ?? "",
                }),
              });
              const json = await r.json();
              if (json.found) {
                powerMap.set(model, { watts: json.power_watts ?? null, va: json.power_va ?? null });
              }
            } catch { /* пропускаем ошибки */ }
          })
        );
      }

      // Применяем найденные мощности к оборудованию
      const equipWithPower = equipment.map((e) => {
        if (e.power_watts === null && e.power_va === null && powerMap.has(e.model)) {
          const p = powerMap.get(e.model)!;
          return { ...e, power_watts: p.watts, power_va: p.va };
        }
        return e;
      });

      // 5. Удаляем старое оборудование и вставляем новое
      await supabase.from("site_equipment_cache").delete().eq("site_id", dbSiteId);

      if (equipWithPower.length > 0) {
        await supabase.from("site_equipment_cache").insert(
          equipWithPower.map((e) => ({ ...e, site_id: dbSiteId, synced_at: new Date().toISOString() }))
        );
      }

      results.push({ site_id: siteId, status: "ok" });
    } catch (err) {
      results.push({ site_id: siteId, status: "error", error: String(err) });
    }

    // Небольшая пауза между запросами чтобы не нагружать APEX-сервер
    await new Promise((r) => setTimeout(r, 300));
  }

  return new Response(JSON.stringify({ synced: results.length, results }), {
    headers: { "Content-Type": "application/json" },
  });
});
