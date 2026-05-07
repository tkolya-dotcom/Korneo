
import { createClient } from "jsr:@supabase/supabase-js@2";

const SYSTEM_KEY = "sats";
const ENC_KEY    = Deno.env.get("SATS_CREDS_ENC_KEY") ?? "korneo_default_enc_key_change_me";

const corsHeaders = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
};

async function getAuthUser(req: Request) {
  const authHeader = req.headers.get("authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return null;

  const anonClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
  );
  const { data: { user } } = await anonClient.auth.getUser(authHeader.slice(7));
  return user;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const user = await getAuthUser(req);
  if (!user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: profile } = await supabase
    .from("users")
    .select("id, role")
    .eq("auth_user_id", user.id)
    .single();

  if (!profile || !["manager", "deputy_head", "admin"].includes(profile.role)) {
    return new Response(JSON.stringify({ error: "Forbidden: only manager+ can manage credentials" }), {
      status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (req.method === "GET") {
    const { data } = await supabase
      .from("external_credentials")
      .select("username, password_enc, updated_at, updated_by")
      .eq("system_key", SYSTEM_KEY)
      .maybeSingle();

    if (!data) {
      return new Response(JSON.stringify({ configured: false }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    let updatedByName: string | null = null;
    if (data.updated_by) {
      const { data: updater } = await supabase
        .from("users").select("name").eq("id", data.updated_by).single();
      updatedByName = updater?.name ?? null;
    }

    return new Response(JSON.stringify({
      configured:      true,
      username:        data.username,
      has_password:    !!data.password_enc,
      updated_at:      data.updated_at,
      updated_by_name: updatedByName,
    }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }

  if (req.method === "POST") {
    const { username, password } = await req.json();

    if (!username || !password) {
      return new Response(JSON.stringify({ error: "username and password required" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { error } = await supabase.rpc("upsert_external_credential", {
      p_system_key: SYSTEM_KEY,
      p_username:   username.trim(),
      p_password:   password,
      p_user_id:    profile.id,
    });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }


    return new Response(JSON.stringify({ saved: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (req.method === "DELETE") {
    await supabase
      .from("external_credentials")
      .delete()
      .eq("system_key", SYSTEM_KEY);

    return new Response(JSON.stringify({ deleted: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ error: "Method not allowed" }), {
    status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
