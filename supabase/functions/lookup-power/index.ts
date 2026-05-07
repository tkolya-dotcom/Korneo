
import { createClient } from "jsr:@supabase/supabase-js@2";

const PERPLEXITY_KEY = Deno.env.get("PERPLEXITY_API_KEY") ?? "";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, PATCH, OPTIONS",
};

async function searchPowerOnline(
  model: string,
  manufacturer: string,
  deviceType: string,
): Promise<{ watts: number | null; va: number | null; url: string; snippet: string; confidence: string } | null> {
  if (!PERPLEXITY_KEY) return null;

  const query = [
    `РЅРѕРјРёРЅР°Р»СЊРЅР°СЏ РїРѕС‚СЂРµР±Р»СЏРµРјР°СЏ РјРѕС‰РЅРѕСЃС‚СЊ ${manufacturer} ${model}`,
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
              "РўС‹ РёРЅР¶РµРЅРµСЂРЅС‹Р№ СЃРїСЂР°РІРѕС‡РЅРёРє. РџРѕР»СЊР·РѕРІР°С‚РµР»СЊ СЃРїСЂР°С€РёРІР°РµС‚ Рѕ РїРѕС‚СЂРµР±Р»СЏРµРјРѕР№ РјРѕС‰РЅРѕСЃС‚Рё РѕР±РѕСЂСѓРґРѕРІР°РЅРёСЏ.",
              "РћС‚РІРµС‡Р°Р№ РўРћР›Р¬РљРћ РІ С„РѕСЂРјР°С‚Рµ JSON (Р±РµР· markdown, Р±РµР· РїРѕСЏСЃРЅРµРЅРёР№):",
              '{ "power_watts": <С‡РёСЃР»Рѕ РёР»Рё null>, "power_va": <С‡РёСЃР»Рѕ РёР»Рё null>,',
              '  "confidence": "confirmed|estimated", "snippet": "<1-2 РїСЂРµРґР»РѕР¶РµРЅРёСЏ РѕС‚РєСѓРґР° РІР·СЏС‚Рѕ>" }',
              "power_watts вЂ” РґР»СЏ РѕР±С‹С‡РЅРѕРіРѕ РѕР±РѕСЂСѓРґРѕРІР°РЅРёСЏ (Р’С‚), power_va вЂ” РґР»СЏ РР‘Рџ (Р’Рђ).",
              "Р•СЃР»Рё РґР°РЅРЅС‹Рµ С‚РѕС‡РЅРѕ РёР· РґР°С‚Р°С€РёС‚Р°/РґРѕРєСѓРјРµРЅС‚Р°С†РёРё вЂ” confidence=confirmed, РµСЃР»Рё РёР· РѕР±Р·РѕСЂРѕРІ/С„РѕСЂСѓРјРѕРІ вЂ” estimated.",
              "Р•СЃР»Рё РґР°РЅРЅС‹С… РЅРµС‚ СЃРѕРІСЃРµРј вЂ” РІРµСЂРЅРё { power_watts: null, power_va: null, confidence: null, snippet: null }",
            ].join(" "),
          },
          {
            role:    "user",
            content: `РџРѕС‚СЂРµР±Р»СЏРµРјР°СЏ РјРѕС‰РЅРѕСЃС‚СЊ: ${manufacturer} ${model} (С‚РёРї: ${deviceType})`,
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method === "PATCH") {
    const body = await req.json();
    const { model, power_watts, power_va, notes } = body;

    if (!model) {
      return new Response(JSON.stringify({ error: "model required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

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

  const { model, manufacturer, device_type } = await req.json();

  if (!model) {
    return new Response(JSON.stringify({ error: "model required" }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const modelClean = model.trim();

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

  const webResult = await searchPowerOnline(
    modelClean,
    manufacturer ?? "",
    device_type  ?? "",
  );

  if (webResult) {
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

  return new Response(JSON.stringify({ found: false }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
