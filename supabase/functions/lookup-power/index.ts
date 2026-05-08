/**
 * Edge Function: lookup-power
 *
 * Ищет номинальную мощность оборудования по модели:
 *   1. Сначала проверяет таблицу power_specs (кэш)
 *   2. Если нет — ищет в интернете через Perplexity AI (sonar)
 *   3. Сохраняет найденное в power_specs с source='web'
 *   4. Если нигде нет — возвращает { found: false } → UI показывает ручной ввод
 *
 * POST /functions/v1/lookup-power
 * Body: { "model": "Eltex MES3348", "manufacturer": "Eltex", "device_type": "Коммутатор" }
 *
 * Response:
 *   { found: true,  power_watts, power_va, source, confidence, source_url, snippet }
 *   { found: false }
 *
 * PATCH /functions/v1/lookup-power   — ручное сохранение мощности менеджером
 * Body: { "model": "...", "power_watts": 43, "notes": "..." }
 */

import { createClient } from "jsr:@supabase/supabase-js@2";

const PERPLEXITY_KEY = Deno.env.get("PERPLEXITY_API_KEY") ?? "";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ── CORS ─────────────────────────────────────────────────────────────────────
const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, PATCH, OPTIONS",
};

// ── Поиск через Perplexity Sonar ─────────────────────────────────────────────
async function searchPowerOnline(
  model: string,
  manufacturer: string,
  deviceType: string,
): Promise<{ watts: number | null; va: number | null; url: string; snippet: string; confidence: string } | null> {
  if (!PERPLEXITY_KEY) return null;

  const query = [
    `номинальная потребляемая мощность ${manufacturer} ${model}`,
    `power consumption watts ${manufacturer} ${model} datasheet specifications`,
  ].join(" OR ");

  try {
    const resp = await fetch("https://api.perplexity.ai/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${PERPLEXITY_KEY}`,
        "Content-Type":  "application/json",
      },
      body: JSON.stringify({
        model:    "sonar",
        messages: [
          {
            role:    "system",
            content: [
              "Ты инженерный справочник. Пользователь спрашивает о потребляемой мощности оборудования.",
              "Отвечай ТОЛЬКО в формате JSON (без markdown, без пояснений):",
              '{ "power_watts": <число или null>, "power_va": <число или null>,',
              '  "confidence": "confirmed|estimated", "snippet": "<1-2 предложения откуда взято>" }',
              "power_watts — для обычного оборудования (Вт), power_va — для ИБП (ВА).",
              "Если данные точно из даташита/документации — confidence=confirmed, если из обзоров/форумов — estimated.",
              "Если данных нет совсем — верни { power_watts: null, power_va: null, confidence: null, snippet: null }",
            ].join(" "),
          },
          {
            role:    "user",
            content: `Потребляемая мощность: ${manufacturer} ${model} (тип: ${deviceType})`,
          },
        ],
        temperature:  0,
        max_tokens:   256,
        return_citations: true,
      }),
    });

    if (!resp.ok) return null;

    const data = await resp.json();
    const content    = data.choices?.[0]?.message?.content ?? "";
    const citations  = data.citations ?? [];
    const sourceUrl  = citations[0] ?? "";

    // Парсим JSON из ответа модели
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return null;

    const parsed = JSON.parse(jsonMatch[0]);
    const watts  = typeof parsed.power_watts === "number" && parsed.power_watts > 0 ? parsed.power_watts : null;
    const va     = typeof parsed.power_va    === "number" && parsed.power_va    > 0 ? parsed.power_va    : null;

    if (!watts && !va) return null;

    return {
      watts,
      va,
      url:        sourceUrl,
      snippet:    parsed.snippet ?? "",
      confidence: parsed.confidence ?? "estimated",
    };
  } catch {
    return null;
  }
}

// ── Основной обработчик ──────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  // ── PATCH: ручное сохранение мощности ──────────────────────────────────────
  if (req.method === "PATCH") {
    const body = await req.json();
    const { model, power_watts, power_va, notes } = body;

    if (!model) {
      return new Response(JSON.stringify({ error: "model required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Определяем кто сохраняет (для updated_by)
    const authHeader = req.headers.get("authorization") ?? "";
    let userId: string | null = null;
    if (authHeader.startsWith("Bearer ")) {
      const token = authHeader.slice(7);
      const { data: { user } } = await createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_ANON_KEY")!,
      ).auth.getUser(token);
      if (user) {
        const { data: profile } = await supabase
          .from("users").select("id").eq("auth_user_id", user.id).single();
        userId = profile?.id ?? null;
      }
    }

    const { error } = await supabase
      .from("power_specs")
      .upsert({
        model:       model.trim(),
        power_watts: power_watts ?? null,
        power_va:    power_va ?? null,
        source:      "manual",
        confidence:  "manual",
        notes:       notes ?? null,
        updated_by:  userId,
        updated_at:  new Date().toISOString(),
      }, { onConflict: "model" });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ saved: true, source: "manual" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── POST: поиск мощности ────────────────────────────────────────────────────
  const { model, manufacturer, device_type } = await req.json();

  if (!model) {
    return new Response(JSON.stringify({ error: "model required" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const modelClean = model.trim();

  // 1. Проверяем кэш power_specs
  const { data: cached } = await supabase
    .from("power_specs")
    .select("*")
    .eq("model", modelClean)
    .maybeSingle();

  if (cached) {
    return new Response(JSON.stringify({
      found:       true,
      power_watts: cached.power_watts,
      power_va:    cached.power_va,
      source:      cached.source,
      confidence:  cached.confidence,
      source_url:  cached.source_url,
      snippet:     cached.source_snippet,
      from_cache:  true,
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  // 2. Ищем в интернете
  const webResult = await searchPowerOnline(
    modelClean,
    manufacturer ?? "",
    device_type  ?? "",
  );

  if (webResult) {
    // Сохраняем в power_specs
    await supabase.from("power_specs").upsert({
      model:          modelClean,
      manufacturer:   manufacturer ?? null,
      device_type:    device_type  ?? null,
      power_watts:    webResult.watts,
      power_va:       webResult.va,
      source:         "web",
      source_url:     webResult.url,
      source_snippet: webResult.snippet,
      confidence:     webResult.confidence,
    }, { onConflict: "model" });

    return new Response(JSON.stringify({
      found:       true,
      power_watts: webResult.watts,
      power_va:    webResult.va,
      source:      "web",
      confidence:  webResult.confidence,
      source_url:  webResult.url,
      snippet:     webResult.snippet,
      from_cache:  false,
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  // 3. Нигде не нашли
  return new Response(JSON.stringify({ found: false }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
