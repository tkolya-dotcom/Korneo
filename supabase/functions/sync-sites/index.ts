
import { createClient } from "jsr:@supabase/supabase-js@2";

const SATS_BASE    = "https://bi.sats.spb.ru/suremts";
const SATS_USER    = Deno.env.get("SATS_USERNAME") ?? "dispatcher";
const SATS_PASS    = Deno.env.get("SATS_PASSWORD") ?? "";
const SYNC_SECRET  = Deno.env.get("SYNC_SECRET")   ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")  ?? "";
const SERVICE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CATEGORY_MAP: Record<string, string> = {
  "РєРѕРјРјСѓС‚Р°С‚РѕСЂ": "switch",
  "РјР°СЂС€СЂСѓС‚РёР·Р°С‚РѕСЂ": "switch",
  "switch": "switch",
  "router": "switch",
  "РёР±Рї": "ups",
  "ups": "ups",
  "РёСЃС‚РѕС‡РЅРёРє Р±РµСЃРїРµСЂРµР±РѕР№РЅРѕРіРѕ": "ups",
  "РєРѕРЅРґРёС†РёРѕРЅРµСЂ": "ac",
  "СЃРїР»РёС‚": "ac",
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

let apexSession: string | null = null;

async function getApexSession(): Promise<string> {
  if (apexSession) return apexSession;

  const homeResp = await fetch(`${SATS_BASE}/f?p=101`, { redirect: "follow" });
  const homeUrl  = homeResp.url; // f?p=101:5:SESSION::NO:RP::
  const match    = homeUrl.match(/f\?p=101:\d+:(\d+)/);
  if (!match) throw new Error(`РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕР»СѓС‡РёС‚СЊ APEX-СЃРµСЃСЃРёСЋ РёР· URL: ${homeUrl}`);

  apexSession = match[1];

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

async function fetchSiteDetail(siteId: number): Promise<Record<string, string>> {
  const session = await getApexSession();
  const url     = `${SATS_BASE}/f?p=101:8:${session}::NO:RP:P8_ID:${siteId}`;
  const resp    = await fetch(url);
  const html    = await resp.text();

  const extract = (label: string): string => {
    const re = new RegExp(
      `<dt[^>]*>[^<]*${escapeRe(label)}[^<]*<\\/dt>\\s*<dd[^>]*>([\\s\\S]*?)<\\/dd>`,
      "i"
    );
    const m = html.match(re);
    if (!m) return "";
    return m[1].replace(/<[^>]+>/g, "").trim();
  };

  const contacts: Array<{ phone: string; name: string }> = [];
  const contactSection = html.match(/РљРѕРЅС‚Р°РєС‚С‹:?([\s\S]*?)(?:Р Р°СЃРїРѕР»РѕР¶РµРЅРёРµ С€РєР°С„РѕРІ|<\/div>)/i)?.[1] ?? "";
  const phoneRe = /(\+?[\d\s\-]{10,})\s*[вЂ”вЂ“-]\s*([^<\n]+)/g;
  let pm: RegExpExecArray | null;
  while ((pm = phoneRe.exec(contactSection)) !== null) {
    contacts.push({ phone: pm[1].trim(), name: pm[2].trim() });
  }

  const cabinets: Array<{ name: string; floor: string; room: string }> = [];
  const cabSection = html.match(/Р Р°СЃРїРѕР»РѕР¶РµРЅРёРµ С€РєР°С„РѕРІ:?([\s\S]*?)(?:<\/div>|РћР±РѕСЂСѓРґРѕРІР°РЅРёРµ)/i)?.[1] ?? "";
  const cabRe = /([РўРЁ\w\sв„–]+?)\s*(?:в†’|Р­С‚Р°Р¶).*?Р­С‚Р°Р¶:\s*(\d+)[.\s]+РџРѕРјРµС‰РµРЅРёРµ:\s*([^<.\n]+)/gi;
  let cm: RegExpExecArray | null;
  while ((cm = cabRe.exec(cabSection)) !== null) {
    cabinets.push({ name: cm[1].trim(), floor: cm[2].trim(), room: cm[3].trim() });
  }

  return {
    type:            extract("РўРёРї"),
    segment:         extract("РЎРµРіРјРµРЅС‚"),
    status:          extract("РЎС‚Р°С‚СѓСЃ"),
    district:        extract("Р Р°Р№РѕРЅ"),
    address:         extract("РђРґСЂРµСЃ"),
    connection_type: extract("РўРёРї РїРѕРґРєР»СЋС‡РµРЅРёСЏ"),
    commissioned_at: extract("Р”Р°С‚Р° РІРІРѕРґР° РІ СЌРєСЃРїР»СѓР°С‚Р°С†РёСЋ"),
    description:     extract("РћРїРёСЃР°РЅРёРµ"),
    _contacts:       JSON.stringify(contacts),
    _cabinets:       JSON.stringify(cabinets),
  };
}

async function fetchSiteEquipment(siteId: number): Promise<EquipItem[]> {
  const session = await getApexSession();

  const url  = `${SATS_BASE}/f?p=101:8:${session}::NO:RP:P8_ID:${siteId}`;
  const resp = await fetch(url);
  const html = await resp.text();

  const equipPageRe = /f\?p=101:(22|47|56|34):[\d]+::NO:RP:P(?:22|47|56|34)_ID:(\d+)/g;
  const found = new Map<string, { page: string; equipId: string }>();
  let m: RegExpExecArray | null;
  while ((m = equipPageRe.exec(html)) !== null) {
    const key = `${m[1]}_${m[2]}`;
    if (!found.has(key)) found.set(key, { page: m[1], equipId: m[2] });
  }

  const items: EquipItem[] = [];
  const promises = [...found.values()].map(async ({ page, equipId }) => {
    try {
      const item = await fetchEquipCard(page, equipId, session);
      if (item) items.push(item);
    } catch {
    }
  });

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

  const typeStr  = extract("РўРёРї СѓСЃС‚СЂРѕР№СЃС‚РІР°");
  const model    = extract("РњРѕРґРµР»СЊ");
  const category = detectCategory(typeStr, model);

  let powerWatts: number | null = null;
  let powerVa:    number | null = null;

  if (page === "22") {
    const raw = extract("РќРѕРјРёРЅР°Р»СЊРЅР°СЏ РјРѕС‰РЅРѕСЃС‚СЊ");
    const val = parseFloat(raw.replace(/[^\d.]/g, ""));
    if (!isNaN(val) && val > 0) powerWatts = val;
  } else if (page === "47") {
    const raw = extract("РњРѕС‰РЅРѕСЃС‚СЊ");
    const val = parseFloat(raw.replace(/[^\d.]/g, ""));
    if (!isNaN(val) && val > 0) powerVa = val;
  }

  const nameMatch = html.match(/<h1[^>]*>([^<]+)<\/h1>/i);
  const name      = nameMatch ? nameMatch[1].trim() : `equip-${equipId}`;

  const breadcrumb = html.match(/РџР»РѕС‰Р°РґРєРё[\s\S]*?\\([\s\S]*?)\\([^\\<]+)\\[^\\<]+$/m);
  const cabinet    = breadcrumb ? breadcrumb[2].trim() : "";

  return {
    emts_equip_id:    parseInt(equipId),
    name,
    model,
    manufacturer:     extract("Р¤РёСЂРјР° РёР·РіРѕС‚РѕРІРёС‚РµР»СЊ"),
    device_type:      typeStr,
    device_category:  category,
    cabinet,
    status:           extract("РЎС‚Р°С‚СѓСЃ"),
    serial_number:    extract("РЎРµСЂРёР№РЅС‹Р№ РЅРѕРјРµСЂ"),
    inventory_number: extract("РРЅРІРµРЅС‚Р°СЂРЅС‹Р№ РЅРѕРјРµСЂ"),
    power_watts:      powerWatts,
    power_va:         powerVa,
  };
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function parseDate(s: string): string | null {
  if (!s) return null;
  const m = s.match(/^(\d{2})\.(\d{2})\.(\d{4})/);
  if (m) return `${m[3]}-${m[2]}-${m[1]}`;
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Headers": "authorization, x-sync-secret, content-type",
      },
    });
  }

  const authHeader = req.headers.get("authorization") ?? "";
  const syncSecret = req.headers.get("x-sync-secret")  ?? "";
  const isServiceRole = authHeader.includes(Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "____");
  const isSecretOk    = SYNC_SECRET && syncSecret === SYNC_SECRET;

  if (!isServiceRole && !isSecretOk) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let siteIds: number[] = [];

  try {
    const body = await req.json().catch(() => ({}));
    if (Array.isArray(body.site_ids) && body.site_ids.length > 0) {
      siteIds = body.site_ids.map(Number).filter(Boolean);
    }
  } catch { /* С‚РµР»Рѕ РјРѕР¶РµС‚ Р±С‹С‚СЊ РїСѓСЃС‚С‹Рј */ }

  if (siteIds.length === 0) {
    const { data: installs } = await supabase
      .from("installations")
      .select("id_ploshadki, servisnyy_id, title")
      .not("id_ploshadki", "is", null);

    siteIds = (installs ?? [])
      .map((r: Record<string, unknown>) => parseInt(String(r.id_ploshadki)))
      .filter((id: number) => !isNaN(id) && id > 0);
  }

  if (siteIds.length === 0) {
    return new Response(JSON.stringify({ message: "РќРµС‚ РїР»РѕС‰Р°РґРѕРє РґР»СЏ СЃРёРЅС…СЂРѕРЅРёР·Р°С†РёРё" }), { status: 200 });
  }

  const results: Array<{ site_id: number; status: string; error?: string }> = [];

  for (const siteId of siteIds) {
    try {
      const detail = await fetchSiteDetail(siteId);

      const session  = await getApexSession();
      const pageUrl  = `${SATS_BASE}/f?p=101:8:${session}::NO:RP:P8_ID:${siteId}`;
      const pageResp = await fetch(pageUrl);
      const pageHtml = await pageResp.text();

      const titleMatch = pageHtml.match(/<h1[^>]*>([^<]+)<\/h1>/i);
      const fullTitle  = titleMatch ? titleMatch[1].trim() : `Site ${siteId}`;
      const codeMatch  = fullTitle.match(/\[([^\]]+)\]/);
      const emtsCode   = codeMatch ? codeMatch[1] : null;

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

      const equipment = await fetchSiteEquipment(siteId);

      const lookupUrl = `${SUPABASE_URL}/functions/v1/lookup-power`;
      const uniqueModels = [...new Set(
        equipment
          .filter((e) => e.power_watts === null && e.power_va === null && e.model)
          .map((e) => e.model)
      )];

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
            } catch { /* РїСЂРѕРїСѓСЃРєР°РµРј РѕС€РёР±РєРё */ }
          })
        );
      }

      const equipWithPower = equipment.map((e) => {
        if (e.power_watts === null && e.power_va === null && powerMap.has(e.model)) {
          const p = powerMap.get(e.model)!;
          return { ...e, power_watts: p.watts, power_va: p.va };
        }
        return e;
      });

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

    await new Promise((r) => setTimeout(r, 300));
  }

  return new Response(JSON.stringify({ synced: results.length, results }), {
    headers: { "Content-Type": "application/json" },
  });
});
