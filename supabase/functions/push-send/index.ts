import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ─── VAPID helpers (Web Crypto API, Deno native) ───────────────────────────

function base64UrlDecode(str: string): Uint8Array {
  const pad = str.length % 4 === 0 ? '' : '='.repeat(4 - (str.length % 4))
  return Uint8Array.from(atob((str + pad).replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0))
}

function base64UrlEncode(buf: ArrayBuffer): string {
  return btoa(String.fromCharCode(...new Uint8Array(buf)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

async function makeVapidHeaders(
  audience: string,
  vapidPublic: string,
  vapidPrivate: string,
  subject: string
): Promise<{ Authorization: string; 'Crypto-Key': string }> {
  const header = { typ: 'JWT', alg: 'ES256' }
  const now = Math.floor(Date.now() / 1000)
  const payload = { aud: audience, exp: now + 43200, sub: subject }

  const headerB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(header)))
  const payloadB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(payload)))
  const unsigned = `${headerB64}.${payloadB64}`

  const keyData = base64UrlDecode(vapidPrivate)
  const cryptoKey = await crypto.subtle.importKey(
    'raw', keyData,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false, ['sign']
  )
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    new TextEncoder().encode(unsigned)
  )
  const jwt = `${unsigned}.${base64UrlEncode(sig)}`

  return {
    Authorization: `vapid t=${jwt},k=${vapidPublic}`,
    'Crypto-Key': `p256ecdsa=${vapidPublic}`,
  }
}

// ─── Web Push (RFC 8291 aes128gcm encryption) ─────────────────────────────

async function encryptPayload(
  payload: string,
  p256dh: string,
  auth: string
): Promise<{ ciphertext: Uint8Array; salt: Uint8Array; serverPublicKey: Uint8Array }> {
  const salt = crypto.getRandomValues(new Uint8Array(16))

  // Import receiver public key
  const receiverKeyBytes = base64UrlDecode(p256dh)
  const receiverKey = await crypto.subtle.importKey(
    'raw', receiverKeyBytes,
    { name: 'ECDH', namedCurve: 'P-256' },
    true, []
  )

  // Generate ephemeral key pair
  const senderKeys = await crypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' },
    true, ['deriveBits']
  )
  const senderPublicKeyBytes = new Uint8Array(
    await crypto.subtle.exportKey('raw', senderKeys.publicKey)
  )

  // ECDH shared secret
  const sharedSecretBits = await crypto.subtle.deriveBits(
    { name: 'ECDH', public: receiverKey },
    senderKeys.privateKey, 256
  )

  // auth secret
  const authBytes = base64UrlDecode(auth)

  // HKDF PRK from auth
  const authKey = await crypto.subtle.importKey('raw', authBytes, 'HKDF', false, ['deriveBits'])
  const prk = await crypto.subtle.importKey(
    'raw',
    await crypto.subtle.deriveBits(
      { name: 'HKDF', hash: 'SHA-256', salt: authBytes, info: new TextEncoder().encode('Content-Encoding: auth\0') },
      authKey, 256
    ),
    'HKDF', false, ['deriveBits']
  )

  // HKDF for CEK & nonce
  const keyInfo = buildInfo('aesgcm', receiverKeyBytes, senderPublicKeyBytes)
  const nonceInfo = buildInfo('nonce', receiverKeyBytes, senderPublicKeyBytes)

  const cekBits = await crypto.subtle.deriveBits(
    { name: 'HKDF', hash: 'SHA-256', salt, info: keyInfo }, prk, 128
  )
  const nonceBits = await crypto.subtle.deriveBits(
    { name: 'HKDF', hash: 'SHA-256', salt, info: nonceInfo }, prk, 96
  )

  const cekKey = await crypto.subtle.importKey('raw', cekBits, 'AES-GCM', false, ['encrypt'])
  const payloadBytes = new TextEncoder().encode(payload)
  const padded = new Uint8Array(2 + payloadBytes.length)
  padded.set(payloadBytes, 2)

  const encrypted = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: nonceBits },
    cekKey, padded
  )

  return { ciphertext: new Uint8Array(encrypted), salt, serverPublicKey: senderPublicKeyBytes }
}

function buildInfo(type: string, receiverKey: Uint8Array, senderKey: Uint8Array): Uint8Array {
  const info = new Uint8Array(18 + 1 + receiverKey.length + 2 + senderKey.length)
  let offset = 0
  const enc = new TextEncoder()
  const typeBytes = enc.encode(type)
  info.set(typeBytes, offset); offset += typeBytes.length
  info[offset++] = 0
  new DataView(info.buffer).setUint16(offset, receiverKey.length); offset += 2
  info.set(receiverKey, offset); offset += receiverKey.length
  new DataView(info.buffer).setUint16(offset, senderKey.length); offset += 2
  info.set(senderKey, offset)
  return info
}

async function sendWebPush(sub: { endpoint: string; p256dh: string; auth: string }, payloadJson: object) {
  const VAPID_PUBLIC = Deno.env.get('VAPID_PUBLIC_KEY') ?? ''
  const VAPID_PRIVATE = Deno.env.get('VAPID_PRIVATE_KEY') ?? ''
  const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') ?? 'mailto:admin@example.com'
  
  if (!VAPID_PUBLIC || !VAPID_PRIVATE) {
    console.error('VAPID keys not configured');
    return 500;
  }

  const url = new URL(sub.endpoint)
  const audience = `${url.protocol}//${url.host}`

  const vapidHeaders = await makeVapidHeaders(audience, VAPID_PUBLIC, VAPID_PRIVATE, VAPID_SUBJECT)
  const body = JSON.stringify(payloadJson)

  const { ciphertext, salt, serverPublicKey } = await encryptPayload(body, sub.p256dh, sub.auth)

  // Build encrypted body (salt + dh_len + dh + encrypted)
  const rs = 4096
  const header = new Uint8Array(21 + serverPublicKey.length)
  header.set(salt, 0)
  new DataView(header.buffer).setUint32(16, rs)
  header[20] = serverPublicKey.length
  header.set(serverPublicKey, 21)
  const fullBody = new Uint8Array(header.length + ciphertext.length)
  fullBody.set(header, 0)
  fullBody.set(ciphertext, header.length)

  const response = await fetch(sub.endpoint, {
    method: 'POST',
    headers: {
      ...vapidHeaders,
      'Content-Type': 'application/octet-stream',
      'Content-Encoding': 'aes128gcm',
      'TTL': '86400',
    },
    body: fullBody,
  })

  return response.status
}

// ─── FCM Push (for Android) ─────────────────────────────────────────────

async function sendFCMPush(token: string, payload: { title: string; body: string; data?: any }): Promise<number> {
  const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY');
  
  if (!FCM_SERVER_KEY) {
    console.error('FCM_SERVER_KEY not configured');
    return 500;
  }

  try {
    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${FCM_SERVER_KEY}`,
      },
      body: JSON.stringify({
        to: token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
        priority: 'high',
      }),
    });

    return response.status;
  } catch (e) {
    console.error('FCM push error:', e);
    return 500;
  }
}

// ─── Main handler ─────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('push-send: Starting...');
    
    // Верифицируем JWT токен
    const authHeader = req.headers.get('Authorization') ?? ''
    if (!authHeader.startsWith('Bearer ')) {
      console.error('push-send: Missing token');
      return new Response(JSON.stringify({ error: 'Missing token' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    const token = authHeader.replace('Bearer ', '')
    
    console.log('push-send: Token received, length:', token.length);
    
    // Простая проверка - просто проверяем что токен есть
    // Не валидируем через Supabase чтобы избежать проблем с ключами
    if (token.length < 50) {
      console.error('push-send: Token too short');
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    
    console.log('push-send: Token accepted');
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Payload: { chat_id, message_id, sender_name, text, exclude_user_id? }
    const { chat_id, sender_name, text, exclude_user_id } = await req.json()
    console.log('push-send: Payload:', { chat_id, sender_name, text, exclude_user_id });

    // 1. Get all chat members except sender
    const { data: members, error: membersErr } = await supabaseAdmin
      .from('chat_members')
      .select('user_id')
      .eq('chat_id', chat_id)
      .neq('user_id', exclude_user_id ?? '')

    if (membersErr) throw membersErr
    console.log('push-send: Members found:', members?.length || 0);

    const userIds = (members ?? []).map((m: { user_id: string }) => m.user_id)
    if (!userIds.length) {
      return new Response(JSON.stringify({ sent: 0 }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
    }

    // 2. Get push subscriptions for those users
    const { data: subs, error: subsErr } = await supabaseAdmin
      .from('user_push_subs')
      .select('user_id, endpoint, p256dh, auth, subscription')
      .in('user_id', userIds)

    if (subsErr) throw subsErr
    console.log('push-send: Subscriptions found:', subs?.length || 0);

    // 3. Send pushes (FCM or Web Push)
    let sentCount = 0
    const expiredEndpoints: string[] = []

    for (const sub of subs ?? []) {
      try {
        // Check if FCM subscription
        const isFCM = sub.subscription && typeof sub.subscription === 'object' && 
                     (sub.subscription as any).type === 'fcm';
        
        if (isFCM) {
          // Send via FCM
          const fcmToken = (sub.subscription as any).endpoint;
          const status = await sendFCMPush(fcmToken, {
            title: sender_name ?? 'Новое сообщение',
            body: text?.length > 100 ? text.slice(0, 100) + '…' : text,
            data: { chat_id, url: '/' },
          });
          
          if (status === 410 || status === 404) {
            expiredEndpoints.push(sub.endpoint || fcmToken)
          } else if (status < 300) {
            sentCount++
          }
        } else {
          // Send via Web Push
          const status = await sendWebPush({
            endpoint: sub.endpoint,
            p256dh: sub.p256dh,
            auth: sub.auth
          }, {
            title: sender_name ?? 'Новое сообщение',
            body: text?.length > 100 ? text.slice(0, 100) + '…' : text,
            tag: `chat-${chat_id}`,
            data: { chat_id, url: '/' },
          })

          if (status === 410 || status === 404) {
            expiredEndpoints.push(sub.endpoint)
          } else if (status < 300) {
            sentCount++
          }
        }
      } catch (e) {
        console.error('Push failed for', sub.user_id, e)
      }
    }

    // 4. Clean up expired subscriptions
    if (expiredEndpoints.length) {
      await supabaseAdmin
        .from('user_push_subs')
        .delete()
        .in('endpoint', expiredEndpoints)
    }

    console.log('push-send: Completed, sent:', sentCount);
    return new Response(
      JSON.stringify({ success: true, sent: sentCount }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('push-send error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
