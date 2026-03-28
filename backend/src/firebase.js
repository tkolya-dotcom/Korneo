import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Путь к сервисному ключу Firebase
const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || 
  join(__dirname, '../../planner-web-4fec7-6982cfde10af.json');

let adminApp;
let messaging;

// Инициализация Firebase Admin
export function initializeFirebaseAdmin() {
  try {
    // Проверяем существует ли файл сервисного ключа
    if (!fs.existsSync(serviceAccountPath)) {
      console.error('❌ Firebase service account key not found at:', serviceAccountPath);
      return null;
    }

    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

    if (getApps().length === 0) {
      adminApp = initializeApp({
        credential: cert(serviceAccount),
        projectId: serviceAccount.project_id
      });
      console.log('✅ Firebase Admin initialized');
    } else {
      adminApp = getApps()[0];
    }

    messaging = getMessaging(adminApp);
    console.log('✅ Firebase Messaging initialized');
    
    return messaging;
  } catch (error) {
    console.error('❌ Error initializing Firebase Admin:', error);
    return null;
  }
}

// Отправка push уведомления через FCM
export async function sendPushNotification(token, title, body, data = {}) {
  if (!messaging) {
    console.error('Firebase Admin not initialized');
    return { success: false, error: 'Firebase not initialized' };
  }

  try {
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data,
      token: token,
    };

    const response = await messaging.send(message);
    console.log('✅ FCM notification sent successfully:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('❌ Error sending FCM notification:', error);
    return { success: false, error: error.message };
  }
}

// Массовая рассылка уведомлений
export async function sendMulticastNotification(tokens, title, body, data = {}) {
  if (!messaging) {
    console.error('Firebase Admin not initialized');
    return { success: false, error: 'Firebase not initialized' };
  }

  try {
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data,
      tokens: tokens,
    };

    const response = await messaging.sendEachForMulticast(message);
    console.log(`✅ FCM multicast sent: ${response.successCount}/${tokens.length}`);
    return { 
      success: true, 
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses
    };
  } catch (error) {
    console.error('❌ Error sending FCM multicast:', error);
    return { success: false, error: error.message };
  }
}

export { adminApp };
