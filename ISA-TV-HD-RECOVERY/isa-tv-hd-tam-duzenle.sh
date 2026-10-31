#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/ISA-TV-HD-RECOVERY"
cd "$ROOT"

echo "İSA TV HD düzenlemesi başlıyor..."

# Önce güvenli bir yedek al.
BACKUP="$HOME/ISA-TV-HD-PATCH-BACKUP-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
cp -a app/src/main "$BACKUP/"
cp -a app/build.gradle "$BACKUP/" 2>/dev/null || true

ASSET="app/src/main/assets/streamflix"
NEW_ASSET="app/src/main/assets/isa-tv-hd"

if [ -d "$ASSET" ] && [ ! -d "$NEW_ASSET" ]; then
    mv "$ASSET" "$NEW_ASSET"
fi

# CSS dosyasını tarafsız İSA TV HD adına taşı.
if [ -f "$NEW_ASSET/css/netflix-style.css" ]; then
    mv "$NEW_ASSET/css/netflix-style.css" "$NEW_ASSET/css/isa-style.css"
fi

# Eski oynatıcı JS dosyasını kaldır.
rm -f "$NEW_ASSET/js/netflix-player.js"

# --------------------------------------------------
# MAIN ACTIVITY
# --------------------------------------------------

cat > app/src/main/java/com/isatvhd/player/MainActivity.java <<'JAVA'
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
JAVA

# --------------------------------------------------
# PLAYER ACTIVITY
# --------------------------------------------------

cat > app/src/main/java/com/isatvhd/player/PlayerActivity.java <<'JAVA'
package com.isatvhd.player;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.graphics.Color;
import android.graphics.BitmapFactory;
import android.content.res.Configuration;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.TextView;
import android.widget.ImageView;
import android.widget.Button;
import android.net.Uri;
import android.util.Log;

import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.datasource.DefaultHttpDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.ui.PlayerView;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

public class PlayerActivity extends Activity {

    private static final String TAG = "ISATVPlayer";

    private ExoPlayer player;
    private PlayerView playerView;
    private TextView status;
    private Button channelButton;
    private ImageView logo;

    private final Handler handler =
            new Handler(Looper.getMainLooper());

    private final ArrayList<Channel> channels =
            new ArrayList<>();

    private int selectedIndex = 0;

    private static class Channel {
        String name;
        String url;
        String group;
        String logo;
        Map<String, String> headers = new HashMap<>();
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        );

        String queueJson =
                getIntent().getStringExtra("queue_json");

        selectedIndex =
                getIntent().getIntExtra("selected_index", 0);

        try {
            JSONArray array = new JSONArray(
                    queueJson == null ? "[]" : queueJson
            );

            for (int i = 0; i < array.length(); i++) {
                JSONObject object = array.getJSONObject(i);

                Channel channel = new Channel();
                channel.name = object.optString("name", "İsimsiz kanal");
                channel.url = object.optString("url", "");
                channel.group = object.optString("group", "Genel");
                channel.logo = object.optString("logo", "");

                JSONObject h = object.optJSONObject("headers");

                if (h != null) {
                    Iterator<String> keys = h.keys();

                    while (keys.hasNext()) {
                        String key = keys.next();
                        String value = h.optString(key, "");

                        if (!value.isEmpty() &&
                                key.matches("(?i)user-agent|referer|origin")) {
                            channel.headers.put(key, value);
                        }
                    }
                }

                if (channel.url.matches("(?i)^https?://.*")) {
                    channels.add(channel);
                }
            }

        } catch (Exception e) {
            Log.e(TAG, "Kanal listesi okunamadı", e);
        }

        if (channels.isEmpty()) {
            Channel single = new Channel();
            single.name = getIntent().getStringExtra("channel_name");
            single.url = getIntent().getStringExtra("stream_url");

            if (single.name == null) single.name = "İSA TV HD";

            String json = getIntent().getStringExtra("headers_json");

            try {
                JSONObject h = new JSONObject(json == null ? "{}" : json);
                Iterator<String> keys = h.keys();

                while (keys.hasNext()) {
                    String key = keys.next();
                    single.headers.put(key, h.optString(key, ""));
                }
            } catch (Exception ignored) {
            }

            if (single.url != null) channels.add(single);
        }

        if (channels.isEmpty()) {
            finish();
            return;
        }

        if (selectedIndex < 0 || selectedIndex >= channels.size()) {
            selectedIndex = 0;
        }

        createInterface();
        initializePlayer();
        playSelected();
    }

    private void createInterface() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        playerView = new PlayerView(this);
        playerView.setUseController(true);

        root.addView(playerView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        status = new TextView(this);
        status.setTextColor(Color.WHITE);
        status.setTextSize(15);
        status.setGravity(Gravity.CENTER);
        status.setBackgroundColor(0x99000000);
        status.setVisibility(View.GONE);

        root.addView(status, new FrameLayout.LayoutParams(
                -2, -2, Gravity.CENTER
        ));

        channelButton = new Button(this);
        channelButton.setText("KANAL LİSTESİ");
        channelButton.setTextSize(12);
        channelButton.setAllCaps(false);
        channelButton.setOnClickListener(v -> showChannelList());
        channelButton.setVisibility(View.GONE);

        FrameLayout.LayoutParams buttonParams =
                new FrameLayout.LayoutParams(
                        -2, dp(46),
                        Gravity.TOP | Gravity.LEFT
                );

        buttonParams.setMargins(dp(16), dp(18), 0, 0);
        root.addView(channelButton, buttonParams);

        playerView.setControllerVisibilityListener(
                visibility -> channelButton.setVisibility(
                        visibility == View.VISIBLE
                                ? View.VISIBLE : View.GONE
                )
        );

        if (shouldShowTvLogo()) {
            try {
                logo = new ImageView(this);

                try (java.io.InputStream input =
                        getAssets().open("isa-tv-hd/assets/logo.png")) {
                    logo.setImageBitmap(
                            BitmapFactory.decodeStream(input)
                    );
                }

                logo.setScaleType(ImageView.ScaleType.FIT_CENTER);
                logo.setPadding(dp(5), dp(5), dp(5), dp(5));
                logo.setBackgroundColor(0x880F0F0F);
                logo.setContentDescription("İSA TV HD");

                FrameLayout.LayoutParams logoParams =
                        new FrameLayout.LayoutParams(
                                dp(145),
                                dp(90),
                                Gravity.TOP | Gravity.RIGHT
                        );

                logoParams.setMargins(0, dp(18), dp(22), 0);
                root.addView(logo, logoParams);

            } catch (Exception e) {
                Log.e(TAG, "Logo yüklenemedi", e);
            }
        }

        setContentView(root);
    }

    private void initializePlayer() {
        player = new ExoPlayer.Builder(this).build();
        playerView.setPlayer(player);

        player.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int state) {
                if (state == Player.STATE_READY) {
                    status.setVisibility(View.GONE);
                } else if (state == Player.STATE_BUFFERING) {
                    status.setVisibility(View.GONE);
                }
            }

            @Override
            public void onPlayerError(PlaybackException error) {
                Log.e(TAG, "Oynatma hatası: "
                        + error.getErrorCodeName(), error);
                status.setVisibility(View.GONE);
            }
        });
    }

    private void playSelected() {
        if (player == null || selectedIndex < 0 ||
                selectedIndex >= channels.size()) return;

        Channel channel = channels.get(selectedIndex);

        try {
            DefaultHttpDataSource.Factory factory =
                    new DefaultHttpDataSource.Factory()
                            .setUserAgent(
                                    channel.headers.containsKey("User-Agent")
                                    ? channel.headers.get("User-Agent")
                                    : "Mozilla/5.0 (Linux; Android 11) "
                                    + "AppleWebKit/537.36 Chrome/120 Safari/537.36"
                            )
                            .setConnectTimeoutMs(15000)
                            .setReadTimeoutMs(25000)
                            .setAllowCrossProtocolRedirects(true)
                            .setDefaultRequestProperties(channel.headers);

            MediaItem item = new MediaItem.Builder()
                    .setUri(Uri.parse(channel.url))
                    .setMediaId(channel.name)
                    .build();

            player.stop();
            player.clearMediaItems();

            player.setMediaSource(
                    new androidx.media3.exoplayer.source.DefaultMediaSourceFactory(
                            factory
                    ).createMediaSource(item)
            );

            player.prepare();
            player.play();

            setTitle(channel.name);
            status.setVisibility(View.GONE);

        } catch (Exception e) {
            Log.e(TAG, "Yayın başlatılamadı", e);
            status.setVisibility(View.GONE);
        }
    }

    private void showChannelList() {
        if (channels.isEmpty()) return;

        String[] names = new String[channels.size()];

        for (int i = 0; i < channels.size(); i++) {
            Channel c = channels.get(i);
            names[i] = c.name
                    + (c.group == null ? "" : "  •  " + c.group);
        }

        new AlertDialog.Builder(this)
                .setTitle("Kanal Listesi")
                .setSingleChoiceItems(
                        names,
                        selectedIndex,
                        (dialog, which) -> {
                            selectedIndex = which;
                            dialog.dismiss();
                            playSelected();
                        }
                )
                .setNegativeButton("Kapat", null)
                .show();
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

    private int dp(float value) {
        return (int) (
                value * getResources().getDisplayMetrics().density
                + 0.5f
        );
    }

    @Override
    public void onBackPressed() {
        super.onBackPressed();
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (player != null) player.pause();
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacksAndMessages(null);

        if (player != null) {
            player.release();
            player = null;
        }

        super.onDestroy();
    }
}
JAVA

# --------------------------------------------------
# JAVASCRIPT PLAY BRIDGE
# --------------------------------------------------

python - <<'PY'
from pathlib import Path
import re

p = Path("app/src/main/assets/isa-tv-hd/js/isa-sources.js")
s = p.read_text(encoding="utf-8")

start = s.find("function play(channel) {")
end = s.find("function renderChannels()", start)

if start < 0 or end < 0:
    raise SystemExit("play() fonksiyonu bulunamadı; işlem durduruldu.")

new = r'''function play(channel) {
    if (!channel || !channel.url) return;

    let queue = channels;
    let index = queue.indexOf(channel);

    if (index < 0) {
        queue = [channel];
        index = 0;
    }

    if (window.ISATV && window.ISATV.play) {
        window.ISATV.play(
            channel.name,
            channel.url,
            JSON.stringify(channel.headers || {}),
            JSON.stringify(queue),
            index
        );
        return;
    }

    const params = new URLSearchParams({
        stream: channel.url,
        name: channel.name,
        group: channel.group || '',
        logo: channel.logo || ''
    });

    location.href = './player.html?' + params.toString();
}

'''
s = s[:start] + new + s[end:]

# Eski marka sınıfı ile bağlantıyı kaldır.
s = s.replace(
    "if (typeof StreamFlixHomepage !== 'undefined') {",
    "if (typeof StreamFlixHomepage !== 'undefined') {"
)

p.write_text(s, encoding="utf-8")
PY

# --------------------------------------------------
# ANA SAYFA: KATEGORİLERE GÖRE KANALLAR
# --------------------------------------------------

python - <<'PY'
from pathlib import Path

p = Path("app/src/main/assets/isa-tv-hd/js/isa-sources.js")
s = p.read_text(encoding="utf-8")

start = s.find("function renderChannels() {")
end = s.find("function ensureSections()", start)

if start < 0 or end < 0:
    raise SystemExit("renderChannels() bulunamadı.")

new = r'''function renderChannels() {
    const grid = document.getElementById('all-channels');
    if (!grid) return;

    const groups = new Map();

    channels.forEach((channel, index) => {
        const group = channel.group || 'Genel';
        if (!groups.has(group)) groups.set(group, []);
        groups.get(group).push({channel, index});
    });

    grid.innerHTML = channels.length
        ? Array.from(groups.entries()).map(([group, items]) => `
            <section class="isa-channel-category">
                <h2>${escapeHtml(group)}</h2>
                <div class="channels-grid">
                    ${items.map(({channel, index}) => `
                        <div class="channel-card" data-isa-index="${index}">
                            <div class="channel-thumbnail">
                                <div class="channel-placeholder">
                                    <i class="fas fa-tv"></i>
                                </div>
                                ${channel.logo ? `
                                    <img class="channel-thumb-img"
                                         src="${escapeHtml(channel.logo)}"
                                         alt=""
                                         onerror="this.style.display='none'">
                                ` : ''}
                                <div class="channel-overlay">
                                    <button class="play-button" type="button">
                                        <i class="fas fa-play"></i>
                                    </button>
                                </div>
                            </div>
                            <div class="channel-info">
                                <h3 class="channel-name">${escapeHtml(channel.name)}</h3>
                                <p class="channel-group">${escapeHtml(group)}</p>
                            </div>
                        </div>
                    `).join('')}
                </div>
            </section>
        `).join('')
        : '<p>Henüz kanal bulunamadı.</p>';

    grid.querySelectorAll('[data-isa-index]').forEach(card => {
        card.addEventListener('click', () => {
            play(channels[Number(card.dataset.isaIndex)]);
        });
    });

    const search = document.getElementById('search-input');

    if (search && !search.dataset.isaBound) {
        search.dataset.isaBound = '1';

        search.addEventListener('input', () => {
            const term = search.value.toLocaleLowerCase('tr');

            grid.querySelectorAll('[data-isa-index]').forEach(card => {
                const channel =
                    channels[Number(card.dataset.isaIndex)];

                card.style.display =
                    (channel.name + ' ' + channel.group)
                    .toLocaleLowerCase('tr')
                    .includes(term) ? '' : 'none';
            });

            grid.querySelectorAll('.isa-channel-category').forEach(section => {
                const visible = Array.from(
                    section.querySelectorAll('[data-isa-index]')
                ).some(card => card.style.display !== 'none');

                section.style.display = visible ? '' : 'none';
            });
        });
    }
}

'''
s = s[:start] + new + s[end:]

p.write_text(s, encoding="utf-8")
PY

# --------------------------------------------------
# HTML REFERANSLARINI DÜZELT
# --------------------------------------------------

python - <<'PY'
from pathlib import Path

root = Path("app/src/main/assets/isa-tv-hd")

for name in ("index.html", "player.html"):
    p = root / name
    if not p.exists():
        continue

    s = p.read_text(encoding="utf-8", errors="replace")

    s = s.replace("css/netflix-style.css", "css/isa-style.css")
    s = s.replace("js/netflix-player.js", "js/isa-player-source.js")
    s = s.replace("StreamFlix", "İSA TV HD")
    s = s.replace("STREAMFLIX", "ISATVHD")
    s = s.replace("Netflix", "İSA TV HD")
    s = s.replace("NETFLIX", "ISATVHD")

    # Eski web HLS oynatıcısını yükleme.
    s = s.replace(
        '<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>',
        ''
    )

    # Ana sayfa eski kanal yükleyicisini çalıştırma.
    s = s.replace(
        '<script src="js/homepage.js"></script>',
        ''
    )

    s = s.replace(
        '<script src="js/netflix-player.js"></script>',
        ''
    )

    p.write_text(s, encoding="utf-8")

# Eski homepage dosyasını artık yüklemiyoruz.
# Kaynak modülü kendi başına başlatılıyor.
PY

# --------------------------------------------------
# LOGO YOLU
# --------------------------------------------------

sed -i \
's#streamflix/assets/logo.png#isa-tv-hd/assets/logo.png#g' \
app/src/main/java/com/isatvhd/player/PlayerActivity.java 2>/dev/null || true

# --------------------------------------------------
# ESKİ MARKA VE KAYNAK TARAMASI
# --------------------------------------------------

echo
echo "Eski marka referansları taranıyor..."

grep -RniE \
'StreamFlix|STREAMFLIX|netflix-player|netflix-style|streamflixDesktop|STREAMFLIX_RELAY|iptv-org|playlist.*india|playlist.*global' \
app/src/main/assets/isa-tv-hd \
--include='*.js' --include='*.html' --include='*.css' \
|| true

echo
echo "Düzenleme dosyaları:"
echo "MainActivity.java"
echo "PlayerActivity.java"
echo "isa-sources.js"
echo "index.html"
echo "player.html"
echo "Asset klasörü"

echo
echo "Yedek: $BACKUP"
echo "İSA TV HD düzenleme tamamlandı."
