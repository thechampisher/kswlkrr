package com.isatvhd.player;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.net.Uri;
import android.graphics.Color;
import android.graphics.BitmapFactory;
import android.content.res.Configuration;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebChromeClient;
import android.webkit.ValueCallback;
import android.webkit.WebSettings;
import android.webkit.JavascriptInterface;
import android.util.Log;

import org.json.JSONObject;
import org.json.JSONArray;

import java.net.HttpURLConnection;
import java.net.URL;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends Activity {

    private static final String TAG = "ISATV";
    private static final int FILE_REQUEST = 2001;

    private FrameLayout root;
    private WebView webView;
    private ImageView tvLogo;
    private ValueCallback<Uri[]> fileCallback;

    private final ExecutorService networkExecutor =
            Executors.newFixedThreadPool(3);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().setStatusBarColor(Color.BLACK);
        getWindow().setNavigationBarColor(Color.BLACK);

        root = new FrameLayout(this);
        root.setBackgroundColor(Color.rgb(12, 12, 12));

        webView = new WebView(this);
        webView.setBackgroundColor(Color.rgb(12, 12, 12));

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setJavaScriptCanOpenWindowsAutomatically(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setMixedContentMode(
                WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        settings.setLoadsImagesAutomatically(true);
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);

        webView.addJavascriptInterface(new ISATVBridge(), "ISATV");

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                view.evaluateJavascript(
                        "(function(){"
                        + "document.querySelectorAll("
                        + "'.splash-screen,#splash-screen,"
                        + ".splash-overlay,.splash-loader')"
                        + ".forEach(function(e){e.style.display='none';});"
                        + "})();",
                        null
                );
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(
                    WebView view,
                    ValueCallback<Uri[]> callback,
                    FileChooserParams params) {

                if (fileCallback != null) {
                    fileCallback.onReceiveValue(null);
                }

                fileCallback = callback;

                try {
                    startActivityForResult(
                            params.createIntent(),
                            FILE_REQUEST
                    );
                    return true;
                } catch (Exception e) {
                    fileCallback = null;
                    callback.onReceiveValue(null);
                    return false;
                }
            }
        });

        root.addView(webView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        createTvLogo();

        setContentView(root);

        webView.loadUrl(
                "file:///android_asset/isa-tv-hd/index.html"
        );
    }

    private void createTvLogo() {
        if (!shouldShowTvLogo()) return;

        try {
            tvLogo = new ImageView(this);

            try (java.io.InputStream input =
                    getAssets().open("isa-tv-hd/assets/logo.png")) {
                tvLogo.setImageBitmap(
                        BitmapFactory.decodeStream(input)
                );
            }

            tvLogo.setScaleType(ImageView.ScaleType.FIT_CENTER);
            tvLogo.setPadding(dp(5), dp(5), dp(5), dp(5));
            tvLogo.setBackgroundColor(0x880F0F0F);
            tvLogo.setContentDescription("İSA TV HD");

            FrameLayout.LayoutParams params =
                    new FrameLayout.LayoutParams(
                            dp(145),
                            dp(90),
                            Gravity.TOP | Gravity.RIGHT
                    );

            params.setMargins(0, dp(16), dp(22), 0);
            root.addView(tvLogo, params);

        } catch (Exception e) {
            Log.e(TAG, "TV logosu yüklenemedi", e);
        }
    }

    private int dp(float value) {
        return (int) (
                value * getResources().getDisplayMetrics().density
                + 0.5f
        );
    }

    private boolean shouldShowTvLogo() {
        Configuration c = getResources().getConfiguration();

        boolean landscape =
                c.orientation == Configuration.ORIENTATION_LANDSCAPE;

        boolean television =
                (c.uiMode & Configuration.UI_MODE_TYPE_MASK)
                == Configuration.UI_MODE_TYPE_TELEVISION;

        boolean tablet = c.smallestScreenWidthDp >= 600;

        return landscape && (television || tablet);
    }

    public class ISATVBridge {

        @JavascriptInterface
        public void play(
                String name,
                String url,
                String headersJson,
                String queueJson,
                int selectedIndex) {

            runOnUiThread(() -> {
                if (url == null ||
                        !url.matches("(?i)^https?://.*")) {
                    return;
                }

                Intent intent = new Intent(
                        MainActivity.this,
                        PlayerActivity.class
                );

                intent.putExtra("stream_url", url);
                intent.putExtra(
                        "channel_name",
                        name == null ? "İSA TV HD" : name
                );
                intent.putExtra(
                        "headers_json",
                        headersJson == null ? "{}" : headersJson
                );
                
try {
    java.io.File queueFile = new java.io.File(
            getCacheDir(),
            "isa-player-queue.json"
    );

    try (java.io.FileOutputStream output =
                 new java.io.FileOutputStream(queueFile, false)) {
        output.write(
                (queueJson == null ? "[]" : queueJson)
                        .getBytes(java.nio.charset.StandardCharsets.UTF_8)
        );
        output.flush();
    }

    intent.putExtra("queue_file", queueFile.getAbsolutePath());
    intent.putExtra("selected_index", selectedIndex);
    startActivity(intent);

} catch (Exception e) {
    android.util.Log.e("ISATV", "Kanal kuyruğu aktarılamadı", e);
}

            });
        }


        @JavascriptInterface
        public String getFavorites() {
            return getSharedPreferences("isa_tv_data", MODE_PRIVATE)
                    .getString("favorites", "[]");
        }

        @JavascriptInterface
        public void setFavorite(String channelJson, boolean favorite) {
            try {
                JSONObject channel = new JSONObject(channelJson);
                String url = channel.optString("url", "");
                if (url.isEmpty()) return;

                android.content.SharedPreferences prefs =
                        getSharedPreferences("isa_tv_data", MODE_PRIVATE);

                JSONArray old = new JSONArray(prefs.getString("favorites", "[]"));
                JSONArray updated = new JSONArray();

                for (int i = 0; i < old.length(); i++) {
                    JSONObject item = old.optJSONObject(i);
                    if (item == null) continue;
                    if (!url.equals(item.optString("url", ""))) {
                        updated.put(item);
                    }
                }

                if (favorite) updated.put(channel);

                prefs.edit().putString("favorites", updated.toString()).apply();
            } catch (Exception e) {
                Log.e(TAG, "Favori kaydedilemedi", e);
            }
        }

        @JavascriptInterface
public void fetchText(String address, String callbackId) {
    networkExecutor.execute(() -> {
        String result = null;
        String error = null;

        for (int attempt = 1; attempt <= 3; attempt++) {
            HttpURLConnection connection = null;

            try {
                URL url = new URL(address);

                if (!"http".equalsIgnoreCase(url.getProtocol())
                        && !"https".equalsIgnoreCase(url.getProtocol())) {
                    throw new Exception("HTTP/HTTPS adresi gerekli.");
                }

                connection = (HttpURLConnection) url.openConnection();
                connection.setConnectTimeout(20000);
                connection.setReadTimeout(40000);
                connection.setRequestMethod("GET");
                connection.setInstanceFollowRedirects(true);
                connection.setRequestProperty("Accept", "*/*");
                connection.setRequestProperty("Accept-Encoding", "identity");
                connection.setRequestProperty(
                    "User-Agent",
                    "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 "
                    + "(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36"
                );

                int code = connection.getResponseCode();

                if (code < 200 || code >= 300) {
                    throw new java.io.IOException("HTTP " + code);
                }

                StringBuilder output = new StringBuilder();

                try (BufferedReader reader = new BufferedReader(
                        new InputStreamReader(
                            connection.getInputStream(),
                            StandardCharsets.UTF_8))) {

                    String line;
                    while ((line = reader.readLine()) != null) {
                        output.append(line).append('\n');

                        if (output.length() > 15 * 1024 * 1024) {
                            throw new Exception("Kaynak 15 MB sınırını aştı.");
                        }
                    }
                }

                result = output.toString();
                error = null;
                break;

            } catch (Exception e) {
                error = e.getMessage();
                Log.w(TAG, "Kaynak indirme denemesi " + attempt + "/3", e);

                if (attempt < 3) {
                    try {
                        Thread.sleep(attempt * 1200L);
                    } catch (InterruptedException interrupted) {
                        Thread.currentThread().interrupt();
                        error = "İşlem iptal edildi.";
                        break;
                    }
                }
            } finally {
                if (connection != null) {
                    connection.disconnect();
                }
            }
        }

        final String response = result;
        final String failure = error;
        final String safeId = callbackId == null
                ? "0"
                : callbackId.replaceAll("[^0-9]", "");

        runOnUiThread(() -> {
            if (webView == null) return;

            String js = "window.__isaFetchDone("
                    + safeId + ","
                    + JSONObject.quote(response) + ","
                    + JSONObject.quote(failure) + ");";

            webView.evaluateJavascript(js, null);
        });
    });
}



                @JavascriptInterface
        public void openPage(String address) {
            if (address == null || !(address.startsWith("https://") || address.startsWith("http://"))) return;
            runOnUiThread(() -> {
                try {
                    Intent browser = new Intent(Intent.ACTION_VIEW, Uri.parse(address));
                    MainActivity.this.startActivity(browser);
                } catch (Exception e) {
                    Log.e(TAG, "Kaynak sayfası açılamadı", e);
                }
            });
        }

@JavascriptInterface
        public void cachePut(String key, String value) {
            try {
                java.io.File directory = new java.io.File(
                        getFilesDir(),
                        "isa-source-cache"
                );

                if (!directory.exists()) {
                    directory.mkdirs();
                }

                String fileName = Integer.toHexString(
                        key == null ? 0 : key.hashCode()
                ) + ".cache";

                java.io.File file = new java.io.File(
                        directory,
                        fileName
                );

                try (java.io.FileOutputStream output =
                             new java.io.FileOutputStream(file, false)) {
                    output.write(
                            (value == null ? "" : value)
                                    .getBytes(java.nio.charset.StandardCharsets.UTF_8)
                    );
                    output.flush();
                }

            } catch (Exception e) {
                android.util.Log.e("ISATV", "Önbellek yazma hatası", e);
            }
        }

        @JavascriptInterface
        public void cacheGet(String key, String callbackId) {
            String result = null;
            String error = null;

            try {
                java.io.File directory = new java.io.File(
                        getFilesDir(),
                        "isa-source-cache"
                );

                java.io.File file = new java.io.File(
                        directory,
                        Integer.toHexString(
                                key == null ? 0 : key.hashCode()
                        ) + ".cache"
                );

                if (file.isFile()) {
                    StringBuilder content = new StringBuilder();

                    try (java.io.FileInputStream input =
                                 new java.io.FileInputStream(file)) {
                        byte[] buffer = new byte[8192];
                        int count;

                        while ((count = input.read(buffer)) != -1) {
                            content.append(
                                    new String(
                                            buffer,
                                            0,
                                            count,
                                            java.nio.charset.StandardCharsets.UTF_8
                                    )
                            );
                        }
                    }

                    result = content.toString();
                }

            } catch (Exception e) {
                error = e.getMessage();
            }

            final String finalResult = result;
            final String finalError = error;

            final String safeId = callbackId == null
                    ? "0"
                    : callbackId.replaceAll("[^0-9]", "");

            runOnUiThread(() -> {
                if (webView == null) return;

                String valueJson = finalResult == null
                        ? "null"
                        : org.json.JSONObject.quote(finalResult);

                String errorJson = finalError == null
                        ? "null"
                        : org.json.JSONObject.quote(finalError);

                webView.evaluateJavascript(
                        "window.__isaCacheDone(" +
                                safeId + "," +
                                valueJson + "," +
                                errorJson + ");",
                        null
                );
            });
        }

    }

    @Override
    protected void onActivityResult(
            int requestCode,
            int resultCode,
            Intent data) {

        super.onActivityResult(requestCode, resultCode, data);

        if (requestCode == FILE_REQUEST && fileCallback != null) {
            Uri[] result =
                    WebChromeClient.FileChooserParams.parseResult(
                            resultCode,
                            data
                    );

            fileCallback.onReceiveValue(result);
            fileCallback = null;
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (webView != null) {
            webView.postDelayed(() -> {
                if (webView != null) {
                    webView.evaluateJavascript(
                        "if(window.homepage && typeof window.homepage.restoreLastPlayedChannel === 'function'){" +
                        "window.homepage.restoreLastPlayedChannel();}",
                        null
                    );
                }
            }, 250);
        }
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onDestroy() {
        if (fileCallback != null) {
            fileCallback.onReceiveValue(null);
            fileCallback = null;
        }

        networkExecutor.shutdownNow();

        if (webView != null) {
            webView.destroy();
            webView = null;
        }

        super.onDestroy();
    }
}
