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
                intent.putExtra(
                        "queue_json",
                        queueJson == null ? "[]" : queueJson
                );
                intent.putExtra("selected_index", selectedIndex);

                startActivity(intent);
            });
        }

        @JavascriptInterface
        public void fetchText(String address, String callbackId) {
            networkExecutor.execute(() -> {
                String result = null;
                String error = null;
                HttpURLConnection connection = null;

                try {
                    URL url = new URL(address);

                    if (!url.getProtocol().equalsIgnoreCase("http")
                            && !url.getProtocol().equalsIgnoreCase("https")) {
                        throw new Exception("HTTP/HTTPS adresi gerekli.");
                    }

                    connection = (HttpURLConnection)
                            url.openConnection();

                    connection.setConnectTimeout(15000);
                    connection.setReadTimeout(30000);
                    connection.setRequestMethod("GET");
                    connection.setRequestProperty("Accept", "*/*");
                    connection.setRequestProperty(
                            "User-Agent",
                            "Mozilla/5.0 (Linux; Android 11) "
                            + "AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36"
                    );

                    int code = connection.getResponseCode();

                    if (code < 200 || code >= 300) {
                        throw new Exception("HTTP " + code);
                    }

                    StringBuilder output = new StringBuilder();

                    try (BufferedReader reader =
                            new BufferedReader(
                                    new InputStreamReader(
                                            connection.getInputStream(),
                                            StandardCharsets.UTF_8
                                    )
                            )) {

                        String line;
                        while ((line = reader.readLine()) != null) {
                            output.append(line).append('\n');
                        }
                    }

                    result = output.toString();

                } catch (Exception e) {
                    error = e.getMessage();
                    Log.e(TAG, "Kaynak indirilemedi", e);

                } finally {
                    if (connection != null) {
                        connection.disconnect();
                    }
                }

                final String response = result;
                final String failure = error;

                runOnUiThread(() -> {
                    if (webView == null) return;

                    String safeId =
                            callbackId.replaceAll("[^0-9]", "");

                    String js = "window.__isaFetchDone("
                            + safeId + ","
                            + JSONObject.quote(response)
                            + ","
                            + JSONObject.quote(failure)
                            + ");";

                    webView.evaluateJavascript(js, null);
                });
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
