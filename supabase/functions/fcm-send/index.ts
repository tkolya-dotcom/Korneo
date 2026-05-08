import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('fcm-send: Starting...');
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Payload: { user_id, title, body, data? }
    const { user_id, title, body, data } = await req.json()
    console.log('fcm-send: Payload:', { user_id, title, body, data });

    if (!user_id || !title || !body) {
      throw new Error('Missing required fields: user_id, title, body')
    }

    // 1. Get user's FCM token from database
    const { data: userData, error: userError } = await supabaseAdmin
      .from('users')
      .select('fcm_token')
      .eq('id', user_id)
      .single()

    if (userError || !userData?.fcm_token) {
      console.log('fcm-send: User FCM token not found');
      return new Response(
        JSON.stringify({ 
          error: 'User FCM token not found',
          message: 'Пользователь не зарегистрирован для FCM уведомлений'
        }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // 2. Send FCM notification via Firebase HTTP v1 API
    const FCM_API_URL = `https://fcm.googleapis.com/v1/projects/${Deno.env.get('FIREBASE_PROJECT_ID')}/messages:send`
    
    // Get access token using service account
    const accessToken = await getFirebaseAccessToken()
    
    const fcmMessage = {
      message: {
        token: userData.fcm_token,
        notification: {
          title: title,
          body: body,
        },
        data: data || {},
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      },
    }

    const response = await fetch(FCM_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify(fcmMessage),
    })

    const result = await response.json()

    if (!response.ok) {
      console.error('fcm-send: Firebase API error:', result);
      throw new Error(result.error?.message || 'FCM API error')
    }

    console.log('fcm-send: Success:', result.name);

    // 3. Save to notification_queue
    await supabaseAdmin.from('notification_queue').insert([{
      user_id: user_id,
      title: title,
      body: body,
      type: data?.type || 'custom',
      reference_id: data?.reference_id,
      sent: true,
      sent_at: new Date().toISOString()
    }])

    return new Response(
      JSON.stringify({ 
        success: true, 
        messageId: result.name,
        message: 'Уведомление отправлено успешно'
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('fcm-send error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Helper: Get Firebase access token using service account
async function getFirebaseAccessToken(): Promise<string> {
  const serviceAccountB64 = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  
  if (!serviceAccountB64) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT not configured')
  }

  // Decode base64 to UTF-8 JSON string
  const serviceAccountJson = new TextDecoder().decode(
    Uint8Array.from(atob(serviceAccountB64), c => c.charCodeAt(0))
  )
  
  const serviceAccount = JSON.parse(serviceAccountJson)
  
  // Create JWT for Google OAuth
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  }

  const jwt = await createJWT(payload, serviceAccount.private_key)

  // Exchange JWT for access token
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const data = await response.json()
  
  if (!response.ok) {
    throw new Error(data.error_description || 'Failed to get access token')
  }

  return data.access_token
}

// Helper: Create JWT signed with ES256
async function createJWT(payload: object, privateKey: string): Promise<string> {
  const encoder = new TextEncoder()
  const header = { alg: 'RS256', typ: 'JWT' }
  
  const headerB64 = btoa(JSON.stringify(header))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const payloadB64 = btoa(JSON.stringify(payload))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  
  const unsigned = `${headerB64}.${payloadB64}`
  
  // Import private key
  const keyData = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
  
  // Sign
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    keyData,
    encoder.encode(unsigned)
  )
  
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  
  return `${unsigned}.${signatureB64}`
}

// Helper: Convert PEM to ArrayBuffer
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0)).buffer
}
