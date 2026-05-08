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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',  // Client-side safe
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { chat_id, content } = await req.json()
    const { data: { user } } = await supabaseClient.auth.getUser()  // JWT validation

    if (!user) throw new Error('Unauthorized')

    // Set app context for RLS
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    await supabaseAdmin.rpc('set_config', { name: 'app.current_user_id', value: user.id })

    // Insert message (triggers Realtime)
    const { data: message } = await supabaseClient
      .from('messages')
      .insert({ chat_id, content: { text: content } })
      .select()
      .single()

    if (!message) throw new Error('Failed to send message')

    // Get members except sender for push
    const { data: members } = await supabaseAdmin
      .from('chat_members')
      .select('user_id')
      .eq('chat_id', chat_id)

    const otherMembers = (members || []).filter(m => m.user_id !== user.id).map(m => m.user_id)

    // Get sender name
    const { data: sender } = await supabaseAdmin
      .from('users')
      .select('name')
      .eq('id', user.id)
      .single()

    // Call push-send edge function directly
    if (otherMembers.length > 0) {
      try {
        await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/push-send`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            chat_id,
            sender_name: sender?.name || 'Новое сообщение',
            text: content,
            exclude_user_id: user.id
          })
        })
      } catch (e) {
        console.error('Failed to call push-send:', e)
      }
    }

    return new Response(
      JSON.stringify({ message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: corsHeaders, 'Content-Type': 'application/json' }
    )
  }
})

