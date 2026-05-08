package com.korneo.app;

import android.Manifest;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.PermissionRequest;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.view.WindowManager;
import android.view.View;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.google.firebase.messaging.FirebaseMessaging;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends AppCompatActivity {

    private static final String TAG = "KorneoApp";
    private WebView webView;
    private GeolocationPermissions.Callback geoCallback;
    private String geoOrigin;
    private static final String APP_URL = "https://tkolya-dotcom.github.io/Korneo/";
    private static final int PERMISSION_REQUEST_CODE = 100;

    // JS Bridge — методы вызываются из JavaScript через window.AndroidBridge.*
    public class AndroidBridge {
        @JavascriptInterface
        public void log(String msg) {
            Log.d(TAG, "[WebView] " + msg);
        }

        @JavascriptInterface
        public boolean isNativeApp() {
            return true;
        }

        /**
         * Вызывается из JS после успешной авторизации.
         * Сохраняет userId и authToken для отправки FCM-токена при закрытом приложении.
         */
        @JavascriptInterface
        public void saveUserSession(String userId, String authToken) {
            if (userId != null && !userId.isEmpty() && authToken != null && !authToken.isEmpty()) {
                KorneoMessagingService.saveUserSession(MainActivity.this, userId, authToken);
                Log.d(TAG, "User session saved: " + userId.substring(0, 8) + "...");
                // Если уже есть токен — сразу обновим в Supabase
                injectFCMToken();
            }
        }

        /**
         * Вызывается из JS при выходе из аккаунта.
         */
        @JavascriptInterface
        public void clearUserSession() {
            KorneoMessagingService.clearUserSession(MainActivity.this);
            Log.d(TAG, "User session cleared");
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Fullscreen
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        );
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        );

        createNotificationChannel();

        webView = new WebView(this);
        setContentView(webView);

        // JS Bridge
        webView.addJavascriptInterface(new AndroidBridge(), "AndroidBridge");

        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setGeolocationEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(true);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        // Помечаем что это нативное приложение
        s.setUserAgentString(s.getUserAgentString() + " KorneoApp/1.0");

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                if (url.startsWith("https://tkolya-dotcom.github.io/Korneo")) return false;
                try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); } catch (Exception ignored) {}
                return true;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                // После загрузки страницы — передаём FCM токен в JavaScript
                injectFCMToken();
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onPermissionRequest(PermissionRequest request) {
                request.grant(request.getResources());
            }

            @Override
            public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                geoOrigin = origin;
                geoCallback = callback;
                if (ContextCompat.checkSelfPermission(MainActivity.this, Manifest.permission.ACCESS_FINE_LOCATION)
                        == PackageManager.PERMISSION_GRANTED) {
                    callback.invoke(origin, true, false);
                } else {
                    ActivityCompat.requestPermissions(MainActivity.this,
                        new String[]{Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION},
                        PERMISSION_REQUEST_CODE);
                }
            }
        });

        webView.loadUrl(APP_URL);
        requestAllPermissions();
        // UpdateChecker запускается из onResume
    }

    // Получаем FCM токен нативно и передаём в WebView
    private void injectFCMToken() {
        FirebaseMessaging.getInstance().getToken()
            .addOnCompleteListener(task -> {
                if (!task.isSuccessful()) {
                    Log.w(TAG, "FCM getToken failed", task.getException());
                    return;
                }
                String token = task.getResult();
                Log.d(TAG, "FCM Token obtained: " + token.substring(0, 20) + "...");

                // Сохраняем токен глобально через JS, WebView сохранит в Supabase
                String js = "window._nativeFCMToken = '" + token + "';" +
                    "if(typeof window.saveNativeFCMToken === 'function') {" +
                    "  window.saveNativeFCMToken('" + token + "');" +
                    "}";

                runOnUiThread(() -> webView.evaluateJavascript(js, null));
            });
    }

    private void requestAllPermissions() {
        List<String> needed = new ArrayList<>();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED)
                needed.add(Manifest.permission.POST_NOTIFICATIONS);
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            needed.add(Manifest.permission.ACCESS_FINE_LOCATION);
            needed.add(Manifest.permission.ACCESS_COARSE_LOCATION);
        }
        if (!needed.isEmpty())
            ActivityCompat.requestPermissions(this, needed.toArray(new String[0]), PERMISSION_REQUEST_CODE);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == PERMISSION_REQUEST_CODE) {
            for (int i = 0; i < permissions.length; i++) {
                if ((permissions[i].equals(Manifest.permission.ACCESS_FINE_LOCATION)
                        || permissions[i].equals(Manifest.permission.ACCESS_COARSE_LOCATION))
                        && geoCallback != null) {
                    geoCallback.invoke(geoOrigin, grantResults[i] == PackageManager.PERMISSION_GRANTED, false);
                    geoCallback = null;
                }
            }
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                "korneo_notifications", "Корнео уведомления", NotificationManager.IMPORTANCE_HIGH);
            ch.setDescription("Задачи, чаты, монтажи");
            ch.enableVibration(true);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(ch);
        }
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }

    private boolean updateCheckedThisSession = false;

    @Override
    protected void onResume() {
        super.onResume();
        if (webView != null) webView.onResume();
        // Check for update once per session (first resume after cold start)
        if (!updateCheckedThisSession) {
            updateCheckedThisSession = true;
            new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(
                () -> new UpdateChecker(this).checkForUpdate(), 3000);
        }
    }
    @Override protected void onPause()  { super.onPause();  if (webView != null) webView.onPause(); }
}
