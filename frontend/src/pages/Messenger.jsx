import React, { useState, useEffect, useRef, useCallback } from 'react'
import { useAuth } from '../context/AuthContext'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { supabase } from '../config/supabase.js'
import { initMessenger, loadChats, loadMessages, subscribeToMessages, sendMessage } from '../utils/chat'


const Messenger = () => {
  const [searchParams, setSearchParams] = useSearchParams()
  const navigate = useNavigate()
  const [chats, setChats] = useState([])
  const [messages, setMessages] = useState([])
  const [selectedChat, setSelectedChat] = useState(null)
  const [newMsg, setNewMsg] = useState('')
  const [targetUserId, setTargetUserId] = useState(null)
  const messagesEndRef = useRef(null)
  const { user } = useAuth()

  useEffect(() => {
    if (user?.id) {
      initMessenger(user.id)
    }
  }, [user])

  useEffect(() => {
    const userId = searchParams.get('user')
    if (userId && userId !== user?.id) {
      setTargetUserId(userId)
      createPrivateChat(userId)
    }
  }, [searchParams.get('user'), user?.id])

  const refreshChats = useCallback(async () => {
    const chatList = await loadChats()
    setChats(chatList)
  }, [])

  useEffect(() => {
    refreshChats()
  }, [])

  useEffect(() => {
    if (selectedChat) {
      loadMessages(selectedChat.chat_id).then(setMessages)
      const unsub = subscribeToMessages(selectedChat.chat_id, (newMsg) => {
        setMessages(prev => [...prev, newMsg])
      })
      return unsub
    }
  }, [selectedChat])

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const handleSend = async () => {
    if (!newMsg.trim() || !selectedChat) return
    try {
      await sendMessage(newMsg)
      setNewMsg('')
    } catch (err) {
      alert('РћС€РёР±РєР° РѕС‚РїСЂР°РІРєРё: ' + err.message)
    }
  }

  const createPrivateChat = useCallback(async (otherUserId) => {
    try {
      await supabase.rpc('set_config', { name: 'app.current_user_id', value: user.id })
      const { data: chatId } = await supabase.rpc('create_private_chat', { other_user_id: otherUserId })
      if (chatId) {
        await refreshChats()
        setSelectedChat({ chat_id: chatId })
        setSearchParams({})
      }
    } catch (err) {
      console.error('Create private chat error:', err)
      alert('РћС€РёР±РєР° СЃРѕР·РґР°РЅРёСЏ С‡Р°С‚Р°: ' + err.message)
    }
  }, [user.id, setSearchParams])

  return (
    <div className="messenger-container">
      <div className="chat-sidebar">
        <h3>Р§Р°С‚С‹</h3>
        <div className="chat-list">
          {chats.map(chat => (
            <div key={chat.chat_id} className={`chat-item ${selectedChat?.chat_id === chat.chat_id ? 'selected' : ''}`} onClick={() => setSelectedChat(chat)}>
              <strong>{chat.chats.name || 'Р§Р°С‚'}</strong>
              {chat.last_message && (
                <small>{chat.last_message.sender.name}: {chat.last_message.content.text}</small>
              )}
            </div>
          ))}
        </div>
        <button className="new-chat-btn" onClick={() => setTargetUserId(null)}>рџ”Ќ РќРѕРІС‹Р№ С‡Р°С‚</button>
      </div>
      <div className="chat-main">
        {selectedChat ? (
          <>
            <div className="chat-header">{selectedChat.chats?.name}</div>
            <div className="messages-list">
              {messages.map(msg => (
                <div key={msg.id} className={`msg-bubble ${msg.user_id === user.id ? 'own' : ''}`}>
                  <strong>{msg.sender?.name}:</strong> {msg.content.text}
                  <small>{new Date(msg.timestamp).toLocaleTimeString()}</small>
                </div>
              ))}
              <div ref={messagesEndRef} />
            </div>
            <div className="chat-input-container">
              <input
                value={newMsg}
                onChange={e => setNewMsg(e.target.value)}
                placeholder="РЎРѕРѕР±С‰РµРЅРёРµ..."
                onKeyPress={e => e.key === 'Enter' && handleSend()}
              />
              <button onClick={handleSend}>РћС‚РїСЂР°РІРёС‚СЊ</button>
            </div>
          </>
        ) : (
          <div className="no-chat">Р’С‹Р±РµСЂРёС‚Рµ С‡Р°С‚</div>
        )}
      </div>
    </div>
  )
}

export default Messenger

