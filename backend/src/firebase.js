import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import fs from 'fs';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || 
  join(__dirname, '../../planner-web-4fec7-6982cfde10af.json');

let adminApp;
let messaging;

export function initializeFirebaseAdmin() {
  try {
    if (!fs.existsSync(serviceAccountPath)) {
      console.error('вќЊ Firebase service account key not found at:', serviceAccountPath);
      return null;
    }

    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));

    if (getApps().length === 0) {
      adminApp = initializeApp({
        credential: cert(serviceAccount),
        projectId: serviceAccount.project_id
      });
      console.log('вњ… Firebase Admin initialized');
    } else {
      adminApp = getApps()[0];
    }

    messaging = getMessaging(adminApp);
    console.log('вњ… Firebase Messaging initialized');
    
    return messaging;
  } catch (error) {
    console.error('вќЊ Error initializing Firebase Admin:', error);
    return null;
  }
}

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
    console.log('вњ… FCM notification sent successfully:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('вќЊ Error sending FCM notification:', error);
    return { success: false, error: error.message };
  }
}

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
    console.log(`вњ… FCM multicast sent: ${response.successCount}/${tokens.length}`);
    return { 
      success: true, 
      successCount: response.successCount,
      failureCount: response.failureCount,
      responses: response.responses
    };
  } catch (error) {
    console.error('вќЊ Error sending FCM multicast:', error);
    return { success: false, error: error.message };
  }
}

export { adminApp };
