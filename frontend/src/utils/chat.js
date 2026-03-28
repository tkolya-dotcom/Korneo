// src/utils/chat.js - Messenger logic + Supabase realtime
// Импорт: import { initMessenger, getChats, sendMessage, registerPush } from './chat.js'

import { supabase } from '../config/supabase.js'  // adjust path

let currentUserId = null
let currentChatId = null
let messagesSub = null

export const initMessenger = async (userId) => {
  currentUserId = userId
  await loadChats()
  await registerPush()
}

export const loadChats = async () => {
  const { data: members } = await supabase
    .from('chat_members')
    .select(`
      chat_id,
      chats!inner(name, type),
      last_message:messages!chat_members_chat_id_fkey (
        id, content, timestamp, user_id,
        sender:users(id, name)
      )
    `)
    .eq('user_id', currentUserId)
    .order('last_message.timestamp', { ascending: false, referencedTable: 'messages' })

  return members || []
}

export const loadMessages = async (chatId, limit = 50) => {
  const { data } = await supabase
    .from('messages')
    .select('*, sender:users(id, name)')
    .eq('chat_id', chatId)
    .order('timestamp', { ascending: true })
    .limit(limit)

  return data || []
}

export const subscribeToMessages = (chatId, callback) => {
  if (messagesSub) messagesSub.unsubscribe()

  currentChatId = chatId
  messagesSub = supabase
    .channel(`messages:chat-${chatId}`)
    .on('postgres_changes', 
      { event: 'INSERT', schema: 'public', table: 'messages', filter: `chat_id=eq.${chatId}` },
      (payload) => callback(payload.new)
    )
    .subscribe()
}

export const sendMessage = async (content) => {
    const res = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/chat-send`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${localStorage.getItem('token')}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ chat_id: currentChatId, content })
  })

  if (!res.ok) throw new Error(await res.text())
  return res.json()
}

export const registerPush = async () => {
  if (!('serviceWorker' in navigator && 'PushManager' in window)) return

  try {
    const registration = await navigator.serviceWorker.ready
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(import.meta.env.VITE_VAPID_PUBLIC_KEY)
    })

    await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/push-register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ 
        user_id: currentUserId, 
        subscription: subscription.toJSON() 
      })
    })
  } catch (err) {
    console.error('Push registration failed:', err)
  }
}

// https://github.com/web-push-libs/vapid (helper)
export const urlBase64ToUint8Array = (base64String) => {
  const padding = '='.repeat((4 - base64String.length % 4) % 4)
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  return Uint8Array.from([...rawData].map(char => char.charCodeAt(0)))
}

export default { initMessenger, loadChats, loadMessages, subscribeToMessages, sendMessage }

