package com.korneo.app;

import android.app.Activity;
import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.util.Log;

import androidx.appcompat.app.AlertDialog;
import androidx.core.content.FileProvider;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

public class UpdateChecker {

    private static final String TAG = "UpdateChecker";
    private static final String VERSION_URL =
        "https://raw.githubusercontent.com/tkolya-dotcom/Korneo/main/version.json";

    private final Activity activity;

    public UpdateChecker(Activity activity) {
        this.activity = activity;
    }

    public void checkForUpdate() {
        new Thread(() -> {
            try {
                int currentCode = getCurrentVersionCode();
                JSONObject remote = fetchVersionJson();
                if (remote == null) return;

                int remoteCode = remote.getInt("versionCode");
                String remoteName = remote.getString("versionName");
                String downloadUrl = remote.getString("downloadUrl");
                String notes = remote.optString("releaseNotes", "Улучшения и исправления");

                Log.d(TAG, "Current versionCode=" + currentCode + " / Remote versionCode=" + remoteCode);

                if (remoteCode > currentCode) {
                    Log.d(TAG, "Update available: " + remoteName + " URL: " + downloadUrl);
                    activity.runOnUiThread(() -> {
                        // Guard against destroyed activity
                        if (activity.isFinishing() || activity.isDestroyed()) {
                            Log.w(TAG, "Activity is finishing, skipping dialog");
                            return;
                        }
                        showUpdateDialog(remoteName, downloadUrl, notes);
                    });
                } else {
                    Log.d(TAG, "App is up to date (" + currentCode + " >= " + remoteCode + ")");
                }
            } catch (Exception e) {
                Log.e(TAG, "Update check failed: " + e.getMessage(), e);
            }
        }).start();
    }

    @SuppressWarnings("deprecation")
    private int getCurrentVersionCode() {
        try {
            PackageManager pm = activity.getPackageManager();
            String pkg = activity.getPackageName();
            int code;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                code = (int) pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0)).getLongVersionCode();
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                code = (int) pm.getPackageInfo(pkg, 0).getLongVersionCode();
            } else {
                code = pm.getPackageInfo(pkg, 0).versionCode;
            }
            Log.d(TAG, "Current versionCode: " + code);
            return code;
        } catch (PackageManager.NameNotFoundException e) {
            Log.e(TAG, "getPackageInfo failed", e);
            return 0;
        }
    }

    private JSONObject fetchVersionJson() {
        try {
            URL url = new URL(VERSION_URL);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setConnectTimeout(10000);
            conn.setReadTimeout(10000);
            conn.setRequestMethod("GET");
            conn.setRequestProperty("Cache-Control", "no-cache");
            conn.setUseCaches(false);
            int code = conn.getResponseCode();
            Log.d(TAG, "version.json HTTP response: " + code);
            if (code != 200) return null;

            BufferedReader reader = new BufferedReader(
                new InputStreamReader(conn.getInputStream()));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) sb.append(line);
            reader.close();
            return new JSONObject(sb.toString());
        } catch (Exception e) {
            Log.e(TAG, "fetchVersionJson failed", e);
            return null;
        }
    }

    private void showUpdateDialog(String version, String downloadUrl, String notes) {
        new AlertDialog.Builder(activity)
            .setTitle("🆕 Доступно обновление v" + version)
            .setMessage(notes + "\n\nОбновить приложение сейчас?")
            .setPositiveButton("Обновить", (d, w) -> downloadAndInstall(downloadUrl))
            .setNegativeButton("Позже", null)
            .setCancelable(true)
            .show();
    }

    private void downloadAndInstall(String downloadUrl) {
        try {
            DownloadManager.Request request = new DownloadManager.Request(Uri.parse(downloadUrl));
            request.setTitle("Загрузка Корнео");
            request.setDescription("Обновление приложения...");
            request.setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
            request.setDestinationInExternalPublicDir(
                Environment.DIRECTORY_DOWNLOADS, "korneo-update.apk");
            request.setMimeType("application/vnd.android.package-archive");

            DownloadManager dm = (DownloadManager)
                activity.getSystemService(Context.DOWNLOAD_SERVICE);
            long downloadId = dm.enqueue(request);

            // Слушаем завершение скачивания
            BroadcastReceiver receiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context ctx, Intent intent) {
                    long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
                    if (id == downloadId) {
                        installApk(ctx);
                        ctx.unregisterReceiver(this);
                    }
                }
            };

            activity.registerReceiver(receiver,
                new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE),
                Context.RECEIVER_NOT_EXPORTED);

        } catch (Exception e) {
            Log.e(TAG, "Download failed", e);
        }
    }

    private void installApk(Context ctx) {
        File apk = new File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "korneo-update.apk");

        if (!apk.exists()) {
            Log.e(TAG, "APK not found after download");
            return;
        }

        Intent install = new Intent(Intent.ACTION_VIEW);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Uri uri = FileProvider.getUriForFile(ctx,
                ctx.getPackageName() + ".fileprovider", apk);
            install.setDataAndType(uri,
                "application/vnd.android.package-archive");
            install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } else {
            install.setDataAndType(Uri.fromFile(apk),
                "application/vnd.android.package-archive");
        }
        install.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        ctx.startActivity(install);
    }
}
