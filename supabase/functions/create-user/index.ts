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
    console.log('create-user: Starting...');
    
    // Используем SERVICE_ROLE_KEY для всех операций
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // Получаем Authorization header для проверки роли
    const authHeader = req.headers.get('Authorization') ?? ''
    if (!authHeader.startsWith('Bearer ')) {
      console.error('create-user: Missing token');
      return new Response(JSON.stringify({ error: 'Missing token' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    const token = authHeader.replace('Bearer ', '')
    
    console.log('create-user: Token received, length:', token.length);
    
    // Извлекаем user_id из токена через Supabase API
    const url = `${Deno.env.get('SUPABASE_URL')}/auth/v1/user`
    const userResp = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'apikey': Deno.env.get('SUPABASE_ANON_KEY') ?? ''
      }
    })
    
    if (!userResp.ok) {
      console.error('create-user: Failed to get user from Auth API');
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    
    const userData = await userResp.json()
    const userId = userData.id
    
    console.log('create-user: User ID from token:', userId);
    
    // Проверяем что текущий пользователь - manager
    const { data: currentUser, error: userErr } = await supabaseClient
      .from('users')
      .select('role')
      .eq('id', userId)
      .single()
    
    if (userErr || !currentUser || currentUser.role !== 'manager') {
      console.error('create-user: User is not manager');
      return new Response(JSON.stringify({ error: 'Only manager can create users' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    
    console.log('create-user: Manager verified, proceeding...');

    const { email, password, name, role } = await req.json()

    // Валидация
    if (!email || !password || !name || !role) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (password.length < 6) {
      return new Response(JSON.stringify({ error: 'Password must be at least 6 characters' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Проверяем допустимые роли
    const allowedRoles = ['manager', 'deputy_head', 'worker', 'engineer', 'support']
    if (!allowedRoles.includes(role)) {
      return new Response(JSON.stringify({ error: 'Invalid role' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Создаем пользователя в auth.users через admin API
    const { data: authData, error: createErr } = await supabaseClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { name, role }
    })

    if (createErr) {
      return new Response(JSON.stringify({ error: createErr.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Создаем профиль в public.users
    const { error: profileErr } = await supabaseClient
      .from('users')
      .insert({
        id: authData.user.id,
        email,
        name,
        role
      })

    if (profileErr) {
      // Откатываем создание auth пользователя если не удалось создать профиль
      await supabaseClient.auth.admin.deleteUser(authData.user.id)
      return new Response(JSON.stringify({ error: profileErr.message }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    return new Response(
      JSON.stringify({ success: true, user_id: authData.user.id }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
