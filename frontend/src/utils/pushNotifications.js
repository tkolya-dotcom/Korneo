// Backend function to send push notifications
// Add this to your backend or use as a Supabase Edge Function

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const vapidPrivateKey = process.env.VAPID_PRIVATE_KEY;
const vapidSubject = process.env.VAPID_SUBJECT;

export async function sendPushNotification(userId, title, body) {
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    try {
        // Get user's push subscriptions
        const { data: subscriptions, error: fetchError } = await supabase
            .from('user_push_subscriptions')
            .select('*')
            .eq('user_id', userId);
        
        if (fetchError) throw fetchError;
        if (!subscriptions || subscriptions.length === 0) {
            console.log(`No push subscriptions for user ${userId}`);
            return false;
        }
        
        // Send push notification to each subscription
        const webPush = require('web-push');
        
        webPush.setVapidDetails(
            `mailto:${vapidSubject}`,
            'YOUR_VAPID_PUBLIC_KEY',
            vapidPrivateKey
        );
        
        const payload = JSON.stringify({
            title,
            body,
            icon: '/icon-192.png',
            badge: '/icon-192.png'
        });
        
        const promises = subscriptions.map(async (sub) => {
            try {
                await webPush.sendNotification(
                    {
                        endpoint: sub.endpoint,
                        keys: {
                            p256dh: sub.p256dh,
                            auth: sub.auth
                        }
                    },
                    payload
                );
                console.log(`Push sent to ${sub.endpoint}`);
            } catch (error) {
                console.error(`Failed to send push to ${sub.endpoint}:`, error.message);
                // Remove invalid subscription
                if (error.statusCode === 410) {
                    await supabase
                        .from('user_push_subscriptions')
                        .delete()
                        .eq('id', sub.id);
                }
            }
        });
        
        await Promise.all(promises);
        return true;
    } catch (error) {
        console.error('Error sending push notification:', error);
        return false;
    }
}

// Example usage in task creation
export async function notifyTaskAssignment(taskId) {
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    
    // Get task with assignee
    const { data: task } = await supabase
        .from('tasks')
        .select('*, creator:users!tasks_created_by_fkey(name), assignee:users!tasks_assignee_id_fkey(email, name)')
        .eq('id', taskId)
        .single();
    
    if (!task || !task.assignee_id) return;
    
    const title = '📋 Новая задача';
    const body = `Вас назначили на задачу: ${task.title}\nСоздал: ${task.creator?.name || 'Руководитель'}`;
    
    // Send push notification
    await sendPushNotification(task.assignee_id, title, body);
    
    // Also save to notification queue
    await supabase.from('notification_queue').insert({
        user_id: task.assignee_id,
        title,
        body,
        type: 'task_assigned',
        sent: true
    });
}
