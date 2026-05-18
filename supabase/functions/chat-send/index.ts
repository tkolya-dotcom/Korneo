import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function firstString(...values: unknown[]): string | null {
  for (const value of values) {
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function isUuid(value: string | null): boolean {
  return !!value && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function normalizeContent(content: unknown): Record<string, unknown> {
  if (content && typeof content === "object" && !Array.isArray(content)) {
    return content as Record<string, unknown>;
  }
  return { text: String(content ?? "") };
}

function contentText(content: Record<string, unknown>, fallback = ""): string {
  return firstString(
    content.text,
    content.message,
    content.content,
    content.title,
    content.address,
    fallback,
  ) ?? "";
}

function runBackgroundTask(task: Promise<unknown>) {
  const runtime = (globalThis as { EdgeRuntime?: { waitUntil?: (task: Promise<unknown>) => void } }).EdgeRuntime;
  if (runtime?.waitUntil) {
    runtime.waitUntil(task);
    return;
  }
  task.catch((e) => console.error("Background task failed:", e));
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } },
    );

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    const payload = await req.json();
    const chatId = firstString(payload.chat_id, payload.chatId);
    if (!chatId) throw new Error("chat_id is required");

    const { data: authData } = await supabaseClient.auth.getUser();
    const authUser = authData?.user;
    if (!authUser) throw new Error("Unauthorized");

    const requestedSenderId = firstString(payload.sender_id, payload.senderId, payload.user_id, payload.userId);
    let publicUser: { id: string; name?: string | null; email?: string | null; auth_user_id?: string | null } | null = null;

    const byAuth = await supabaseAdmin
      .from("users")
      .select("id,name,email,auth_user_id")
      .eq("auth_user_id", authUser.id)
      .maybeSingle();
    publicUser = byAuth.data ?? null;

    if (!publicUser && authUser.email) {
      const byEmail = await supabaseAdmin
        .from("users")
        .select("id,name,email,auth_user_id")
        .eq("email", authUser.email)
        .maybeSingle();
      publicUser = byEmail.data ?? null;
    }

    if (!publicUser && requestedSenderId && isUuid(requestedSenderId)) {
      const byRequestedId = await supabaseAdmin
        .from("users")
        .select("id,name,email,auth_user_id")
        .eq("id", requestedSenderId)
        .maybeSingle();
      const candidate = byRequestedId.data;
      if (candidate && (candidate.auth_user_id === authUser.id || candidate.email === authUser.email)) {
        publicUser = candidate;
      }
    }

    if (!publicUser?.id) throw new Error("User profile not found");
    const publicUserId = publicUser.id;

    const { data: membership } = await supabaseAdmin
      .from("chat_members")
      .select("chat_id")
      .eq("chat_id", chatId)
      .eq("user_id", publicUserId)
      .maybeSingle();
    if (!membership) throw new Error("Forbidden: user is not a chat member");

    const contentForDb = normalizeContent(payload.content);
    const messageType = firstString(payload.type, contentForDb.type, "text");
    const messageId = firstString(payload.id, payload.client_message_id, payload.clientMessageId);
    const jobId = firstString(payload.job_id, payload.jobId, contentForDb.job_id, contentForDb.jobId);
    const createdAt = firstString(payload.created_at, payload.createdAt);

    const insertRow: Record<string, unknown> = {
      chat_id: chatId,
      user_id: publicUserId,
      content: contentForDb,
    };
    if (isUuid(messageId)) insertRow.id = messageId;
    if (messageType) insertRow.type = messageType;
    if (jobId) insertRow.job_id = jobId;
    if (createdAt) insertRow.created_at = createdAt;

    const { data: message, error: insertError } = await supabaseAdmin
      .from("messages")
      .insert(insertRow)
      .select()
      .single();
    if (insertError) throw insertError;
    if (!message) throw new Error("Failed to send message");

    const { data: members } = await supabaseAdmin
      .from("chat_members")
      .select("user_id")
      .eq("chat_id", chatId);
    const otherMembers = (members ?? [])
      .map((m: { user_id: string }) => m.user_id)
      .filter((userId: string) => userId && userId !== publicUserId);

    if (otherMembers.length > 0) {
      const isWorkCard = messageType === "work_card" || contentForDb.type === "work_card";
      const pushText = isWorkCard
        ? `Работа: ${contentText(contentForDb, "по адресу")}`
        : contentText(contentForDb, "Новое сообщение");

      const pushTask = fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/push-send`, {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            chat_id: chatId,
            message_id: message.id,
            dedupe_key: `${message.id}|${chatId}`,
            sender_id: publicUserId,
            sender_name: publicUser.name || "Новое сообщение",
            text: pushText,
            type: "chat_message",
            exclude_user_id: publicUserId,
          }),
        })
        .then(async (response) => {
          if (!response.ok) {
            const body = await response.text().catch(() => "");
            console.error("push-send failed:", response.status, body);
          }
        })
        .catch((e) => console.error("Failed to call push-send:", e));
      runBackgroundTask(pushTask);
    }

    return new Response(
      JSON.stringify({ message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
