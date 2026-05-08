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
    // Верифицируем JWT вручную, чтобы не зависеть от Gateway
    const authHeader = req.headers.get('Authorization') ?? ''
    if (!authHeader.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Missing token' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    const token = authHeader.replace('Bearer ', '')

    // Проверяем токен через Supabase auth
    const supabaseAuth = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: `Bearer ${token}` } } }
    )
    const { data: { user }, error: authErr } = await supabaseAuth.auth.getUser()
    if (authErr || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { user_id, subscription } = await req.json()

    // Валидация структуры subscription
    if (!subscription || !subscription.endpoint) {
      return new Response(JSON.stringify({ error: 'Missing subscription.endpoint' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    const p256dh = subscription.keys?.p256dh || subscription.p256dh
    const auth = subscription.keys?.auth || subscription.auth
    if (!p256dh || !auth) {
      return new Response(JSON.stringify({ error: 'Missing p256dh or auth keys', received: subscription }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const { error } = await supabaseClient
      .from('user_push_subs')
      .upsert({ 
        user_id: user_id || user.id,
        endpoint: subscription.endpoint,
        p256dh: p256dh,
        auth: auth
      }, { onConflict: 'user_id,endpoint' })

    if (error) throw error

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
