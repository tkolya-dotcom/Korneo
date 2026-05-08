/**
 * push-send — универсальная отправка push-уведомлений
 *
 * Поддерживает:
 *   1. FCM HTTP v1 API (Android / нативные токены из users.fcm_token)
 *   2. FCM через user_push_subs (p256dh = 'fcm' — запись от saveNativeFCMToken)
 *   3. Web Push VAPID (браузеры через user_push_subs)
 *
 * Payload:
 *   chat_id          — отправить всем участникам чата кроме exclude_user_id
 *   target_user_id   — отправить конкретному пользователю (для уведомлений о задачах и т.д.)
 *   sender_name      — заголовок уведомления
 *   text             — тело уведомления
 *   exclude_user_id  — не отправлять этому пользователю (отправитель сообщения)
 *
 * Env vars:
 *   FIREBASE_SERVICE_ACCOUNT — base64(JSON service account)
 *   FIREBASE_PROJECT_ID
 *   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ─── Firebase access token (FCM HTTP v1) ──────────────────────────────────

async function getFirebaseAccessToken(): Promise<string> {
  const b64 = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
  if (!b64) throw new Error("FIREBASE_SERVICE_ACCOUNT not configured");

  const json   = new TextDecoder().decode(Uint8Array.from(atob(b64), c => c.charCodeAt(0)));
  const sa     = JSON.parse(json);
  const now    = Math.floor(Date.now() / 1000);
  const header  = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" })).replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_");
  const payload = btoa(JSON.stringify({
    iss: sa.client_email, sub: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600,
  })).replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_");

  const unsigned = `${header}.${payload}`;
  const keyData  = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(sa.private_key.replace(/-----[^-]+-----/g,"").replace(/\s/g,"")), c => c.charCodeAt(0)).buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", keyData, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/=/g,"").replace(/\+/g,"-").replace(/\//g,"_")}`;

  const res  = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error_description || "Failed to get Firebase token");
  return data.access_token;
}

// ─── FCM HTTP v1 send ───────────────────────────────────────────────────

async function sendFCMv1(fcmToken: string, title: string, body: string, data?: Record<string,string>): Promise<number> {
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
  if (!projectId) { console.error("FIREBASE_PROJECT_ID not set"); return 500; }

  const accessToken = await getFirebaseAccessToken();

  const message = {
    message: {
      token: fcmToken,
      notification: { title, body },
      data: { ...(data || {}), click_action: "FLUTTER_NOTIFICATION_CLICK" },
      android: { priority: "high", notification: { sound: "default", channel_id: "korneo_default" } },
    },
  };

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${accessToken}` },
      body: JSON.stringify(message),
    }
  );

  const result = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.error("FCM v1 error:", result?.error?.message || res.status);
  } else {
    console.log("FCM v1 sent:", result?.name);
  }
  return res.status;
}

// ─── Web Push VAPID ─────────────────────────────────────────────────────

function b64urlDecode(s: string): Uint8Array {
  const pad = s.length % 4 === 0 ? "" : "=".repeat(4 - s.length % 4);
  return Uint8Array.from(atob((s + pad).replace(/-/g,"+").replace(/_/g,"/")), c => c.charCodeAt(0));
}
function b64urlEncode(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g,"-").replace(/\//g,"_").replace(/=/g,"");
}

async function sendWebPush(sub: { endpoint: string; p256dh: string; auth: string }, title: string, body: string, data?: object): Promise<number> {
  const VAPID_PUBLIC  = Deno.env.get("VAPID_PUBLIC_KEY")  ?? "";
  const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE_KEY") ?? "";
  const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT")     ?? "mailto:admin@korneo.app";
  if (!VAPID_PUBLIC || !VAPID_PRIVATE) { console.error("VAPID keys not configured"); return 500; }

  const url      = new URL(sub.endpoint);
  const audience = `${url.protocol}//${url.host}`;
  const now      = Math.floor(Date.now() / 1000);
  const hdr      = b64urlEncode(new TextEncoder().encode(JSON.stringify({ typ:"JWT", alg:"ES256" })));
  const pay      = b64urlEncode(new TextEncoder().encode(JSON.stringify({ aud:audience, exp:now+43200, sub:VAPID_SUBJECT })));
  const unsigned = `${hdr}.${pay}`;
  const vapidKey = await crypto.subtle.importKey("raw", b64urlDecode(VAPID_PRIVATE), { name:"ECDSA", namedCurve:"P-256" }, false, ["sign"]);
  const sig      = await crypto.subtle.sign({ name:"ECDSA", hash:"SHA-256" }, vapidKey, new TextEncoder().encode(unsigned));
  const jwt      = `${unsigned}.${b64urlEncode(sig)}`;

  // Encrypt payload
  const payload  = JSON.stringify({ title, body, data, icon: "./icon-192.png", tag: "korneo" });
  const salt     = crypto.getRandomValues(new Uint8Array(16));
  const recvKey  = await crypto.subtle.importKey("raw", b64urlDecode(sub.p256dh), { name:"ECDH", namedCurve:"P-256" }, true, []);
  const senderKP = await crypto.subtle.generateKey({ name:"ECDH", namedCurve:"P-256" }, true, ["deriveBits"]);
  const senderPub= new Uint8Array(await crypto.subtle.exportKey("raw", senderKP.publicKey));
  const shared   = await crypto.subtle.deriveBits({ name:"ECDH", public: recvKey }, senderKP.privateKey, 256);
  const authBytes= b64urlDecode(sub.auth);
  const authImport = await crypto.subtle.importKey("raw", authBytes, "HKDF", false, ["deriveBits"]);
  const prk = await crypto.subtle.importKey("raw",
    await crypto.subtle.deriveBits({ name:"HKDF", hash:"SHA-256", salt:authBytes, info:new TextEncoder().encode("Content-Encoding: auth\0") }, authImport, 256),
    "HKDF", false, ["deriveBits"]
  );
  const buildInfo = (t:string) => { const b=new Uint8Array(18+1+b64urlDecode(sub.p256dh).length+2+senderPub.length); let o=0; const e=new TextEncoder().encode(t); b.set(e,o);o+=e.length;b[o++]=0;new DataView(b.buffer).setUint16(o,b64urlDecode(sub.p256dh).length);o+=2;b.set(b64urlDecode(sub.p256dh),o);o+=b64urlDecode(sub.p256dh).length;new DataView(b.buffer).setUint16(o,senderPub.length);o+=2;b.set(senderPub,o);return b; };
  const cek  = await crypto.subtle.importKey("raw", await crypto.subtle.deriveBits({name:"HKDF",hash:"SHA-256",salt,info:buildInfo("aesgcm")},prk,128), "AES-GCM",false,["encrypt"]);
  const nonc = await crypto.subtle.deriveBits({name:"HKDF",hash:"SHA-256",salt,info:buildInfo("nonce")},prk,96);
  const pBytes = new TextEncoder().encode(payload); const padded = new Uint8Array(2+pBytes.length); padded.set(pBytes,2);
  const enc   = new Uint8Array(await crypto.subtle.encrypt({name:"AES-GCM",iv:nonc},cek,padded));
  const header= new Uint8Array(21+senderPub.length); header.set(salt,0); new DataView(header.buffer).setUint32(16,4096); header[20]=senderPub.length; header.set(senderPub,21);
  const fullBody = new Uint8Array(header.length+enc.length); fullBody.set(header,0); fullBody.set(enc,header.length);

  const res = await fetch(sub.endpoint, {
    method:"POST",
    headers: { "Authorization":`vapid t=${jwt},k=${VAPID_PUBLIC}`, "Crypto-Key":`p256ecdsa=${VAPID_PUBLIC}`, "Content-Type":"application/octet-stream", "Content-Encoding":"aes128gcm", "TTL":"86400" },
    body: fullBody,
  });
  return res.status;
}

// ─── Main handler ─────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.startsWith("Bearer ") || authHeader.length < 57) {
      return new Response(JSON.stringify({ error: "Missing token" }), { status: 401, headers: { ...corsHeaders, "Content-Type":"application/json" } });
    }

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { chat_id, target_user_id, sender_name, text, exclude_user_id } = await req.json();

    // Собираем user_ids которым отправляем
    let userIds: string[] = [];

    if (target_user_id) {
      // Прямая отправка конкретному пользователю
      userIds = [target_user_id];
    } else if (chat_id) {
      // Все участники чата кроме отправителя
      const { data: members } = await supabase
        .from("chat_members")
        .select("user_id")
        .eq("chat_id", chat_id)
        .neq("user_id", exclude_user_id ?? "00000000-0000-0000-0000-000000000000");
      userIds = (members ?? []).map((m: { user_id: string }) => m.user_id);
    }

    if (!userIds.length) {
      return new Response(JSON.stringify({ sent: 0 }), { headers: { ...corsHeaders, "Content-Type":"application/json" } });
    }

    const title = sender_name ?? "Korneo";
    const body  = text?.length > 120 ? text.slice(0,120) + "…" : (text ?? "");
    let sentCount = 0;

    for (const uid of userIds) {
      // ── 1. Пробуем FCM v1 через users.fcm_token (Android) ──────────────
      const { data: user } = await supabase.from("users").select("fcm_token").eq("id", uid).single();

      if (user?.fcm_token) {
        try {
          const status = await sendFCMv1(user.fcm_token, title, body, { user_id: uid });
          if (status < 300) { sentCount++; continue; }
          // Если токен протух — очищаем
          if (status === 404 || status === 410) {
            await supabase.from("users").update({ fcm_token: null }).eq("id", uid);
          }
        } catch (e) {
          console.error("FCM v1 failed for", uid, e);
        }
      }

      // ── 2. Fallback: Web Push через user_push_subs ───────────────────
      const { data: subs } = await supabase
        .from("user_push_subs")
        .select("endpoint, p256dh, auth")
        .eq("user_id", uid);

      for (const sub of subs ?? []) {
        // Пропускаем FCM-записи (p256dh='fcm') — уже обработали выше
        if (!sub.endpoint || !sub.p256dh || sub.p256dh === "fcm") continue;
        try {
          const status = await sendWebPush(sub, title, body, { chat_id });
          if (status < 300) sentCount++;
          if (status === 404 || status === 410) {
            await supabase.from("user_push_subs").delete().eq("endpoint", sub.endpoint);
          }
        } catch (e) {
          console.error("Web Push failed for", uid, e);
        }
      }
    }

    console.log(`push-send: sent=${sentCount} to ${userIds.length} users`);
    return new Response(JSON.stringify({ success: true, sent: sentCount }), {
      headers: { ...corsHeaders, "Content-Type":"application/json" },
    });

  } catch (err) {
    console.error("push-send error:", err);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500, headers: { ...corsHeaders, "Content-Type":"application/json" },
    });
  }
});
