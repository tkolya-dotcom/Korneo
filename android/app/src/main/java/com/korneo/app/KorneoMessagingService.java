package com.korneo.app;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Build;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import org.json.JSONObject;

import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

public class KorneoMessagingService extends FirebaseMessagingService {

    private static final String TAG          = "KorneoFCM";
    private static final String CHANNEL_ID   = "korneo_notifications";
    private static final String CHANNEL_NAME = "Корнео уведомления";

    // Supabase конфиг — должен совпадать с index.html
    private static final String SUPABASE_URL     = "https://jmxjbdnqnzkzxgsfywha.supabase.co";
    private static final String SUPABASE_ANON_KEY =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
        ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpteGpiZG5xbnprenhnc2Z5d2hhIiwicm9sZSI6ImFub24i" +
        "LCJpYXQiOjE3NzExNTQ0MzQsImV4cCI6MjA4NjczMDQzNH0" +
        ".z6y6DGs9Z6kojQYeAdsgKA-m4pxuoeABdY4rAojPEE4";

    private static final String PREFS_NAME   = "KorneoPrefs";
    private static final String KEY_FCM_TOKEN = "fcm_token";
    private static final String KEY_USER_ID   = "user_id";
    private static final String KEY_AUTH_TOKEN = "auth_token";

    // ── onNewToken: вызывается когда Firebase обновляет токен ────────────────
    // Происходит при первом запуске, переустановке или сбросе токена
    @Override
    public void onNewToken(String token) {
        Log.d(TAG, "New FCM token: " + token.substring(0, 20) + "...");

        // 1. Сохраняем токен локально
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_FCM_TOKEN, token)
            .apply();

        // 2. Если есть сохранённый user_id и auth_token — сразу отправляем в Supabase
        //    Это работает даже при закрытом приложении
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        String userId    = prefs.getString(KEY_USER_ID, null);
        String authToken = prefs.getString(KEY_AUTH_TOKEN, null);

        if (userId != null && authToken != null) {
            sendTokenToSupabase(token, userId, authToken);
        }
        // Если нет сессии — токен сохранён локально и будет передан через WebView при следующем запуске
    }

    // ── onMessageReceived: data-only сообщения при закрытом приложении ───────
    // Notification-сообщения Android показывает сам через FCM SDK (не нужен этот метод)
    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        Log.d(TAG, "Message received from: " + remoteMessage.getFrom());
        createNotificationChannel();

        String title = "Корнео";
        String body  = "";

        if (remoteMessage.getNotification() != null) {
            title = remoteMessage.getNotification().getTitle() != null
                ? remoteMessage.getNotification().getTitle() : "Корнео";
            body  = remoteMessage.getNotification().getBody() != null
                ? remoteMessage.getNotification().getBody() : "";
        } else if (!remoteMessage.getData().isEmpty()) {
            // data-only сообщение — отображаем вручную
            title = remoteMessage.getData().getOrDefault("title", "Корнео");
            body  = remoteMessage.getData().getOrDefault("body",
                    remoteMessage.getData().getOrDefault("message", ""));
        }

        if (!body.isEmpty()) {
            showNotification(title, body);
        }
    }

    // ── Отправка токена в Supabase напрямую (без WebView) ────────────────────
    private void sendTokenToSupabase(String fcmToken, String userId, String authToken) {
        new Thread(() -> {
            try {
                URL url = new URL(SUPABASE_URL + "/rest/v1/users?id=eq." + userId);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("PATCH");
                conn.setRequestProperty("Content-Type", "application/json");
                conn.setRequestProperty("apikey", SUPABASE_ANON_KEY);
                conn.setRequestProperty("Authorization", "Bearer " + authToken);
                conn.setRequestProperty("Prefer", "return=minimal");
                conn.setDoOutput(true);

                JSONObject body = new JSONObject();
                body.put("fcm_token", fcmToken);
                byte[] bodyBytes = body.toString().getBytes(StandardCharsets.UTF_8);
                try (OutputStream os = conn.getOutputStream()) {
                    os.write(bodyBytes);
                }

                int code = conn.getResponseCode();
                Log.d(TAG, "Token update response: " + code);
                conn.disconnect();
            } catch (Exception e) {
                Log.e(TAG, "Failed to send token to Supabase: " + e.getMessage());
            }
        }).start();
    }

    // ── Показ уведомления ─────────────────────────────────────────────────────
    private void showNotification(String title, String body) {
        Intent intent = new Intent(this, MainActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_ONE_SHOT | PendingIntent.FLAG_IMMUTABLE
        );

        Uri soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setSound(soundUri)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent);

        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager != null) {
            manager.notify((int) System.currentTimeMillis(), builder.build());
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH
            );
            channel.setDescription("Задачи, монтажи, чаты");
            channel.enableVibration(true);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) manager.createNotificationChannel(channel);
        }
    }

    // ── Статические методы — вызываются из MainActivity ──────────────────────

    /** Сохраняет сессию пользователя локально для обновления токена при закрытом приложении */
    public static void saveUserSession(Context ctx, String userId, String authToken) {
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_USER_ID, userId)
            .putString(KEY_AUTH_TOKEN, authToken)
            .apply();
        Log.d(TAG, "User session saved for offline token refresh");
    }

    /** Очищает сессию при выходе из аккаунта */
    public static void clearUserSession(Context ctx) {
        ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_USER_ID)
            .remove(KEY_AUTH_TOKEN)
            .apply();
    }

    /** Возвращает сохранённый FCM токен */
    public static String getSavedToken(Context ctx) {
        return ctx.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_FCM_TOKEN, null);
    }
}
