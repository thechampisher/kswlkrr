package com.isatvhd.player;

import android.app.Activity;
import android.widget.LinearLayout;
import android.graphics.drawable.GradientDrawable;
import android.widget.BaseAdapter;
import android.widget.ListView;
import android.app.Dialog;
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
import android.widget.EditText;
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

    private final Map<Integer, ExoPlayer> preloadedPlayers =
            new HashMap<>();

    private final ArrayList<ExoPlayer> standbyPlayers =
            new ArrayList<>();
    private PlayerView playerView;
    private TextView status;
    private Button channelButton;
    private TextView portraitChannelName;
    private TextView portraitLiveBadge;
    private LinearLayout portraitPanel;
    private Button favoriteButton;
private Dialog channelDialog;
    private ImageView logo;
    private android.widget.ProgressBar loadingSpinner;
    private final Runnable hideChannelButton = () -> {
        if (channelButton != null) channelButton.setVisibility(View.GONE);
    };

    private final Handler handler =
            new Handler(Looper.getMainLooper());

    private final ArrayList<Channel> channels =
            new ArrayList<>();

    private int selectedIndex = 0;
    private boolean channelTransitioning = false;

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

        String queueJson = getIntent().getStringExtra("queue_json");

String queueFile = getIntent().getStringExtra("queue_file");

if (queueFile != null) {
    try (java.io.FileInputStream input =
                 new java.io.FileInputStream(queueFile)) {

        java.io.ByteArrayOutputStream bytes =
                new java.io.ByteArrayOutputStream();

        byte[] buffer = new byte[8192];
        int count;

        while ((count = input.read(buffer)) != -1) {
            bytes.write(buffer, 0, count);
        }

        queueJson = bytes.toString("UTF-8");

    } catch (Exception e) {
        android.util.Log.e("ISATV", "Kanal listesi okunamadı", e);
        queueJson = "[]";
    }
}

        selectedIndex =
                getIntent().getIntExtra("selected_index", 0);

        // Ekran döndürülünce son izlenen kanalı geri yükle.
        if (savedInstanceState != null) {
            selectedIndex = savedInstanceState.getInt(
                    "isa_saved_channel_index", selectedIndex);
        }

        // Ekran döndüğünde son izlenen kanalı koru.
        if (savedInstanceState != null) {
            selectedIndex = savedInstanceState.getInt(
                    "isa_saved_channel_index", selectedIndex);
        }

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


    private void applyImmersiveMode() {
        View decor = getWindow().getDecorView();
        decor.setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            | View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        );
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) applyImmersiveMode();
    }

    private void createInterface() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);

        playerView = new PlayerView(this);
        playerView.setUseController(false);

        root.addView(playerView, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        // Ekrana dokunulduğunda yalnızca kanal listesi açılır.
        // Media3 oynatma kontrolleri devre dışıdır.
        View channelTapLayer = new View(this);
        channelTapLayer.setBackgroundColor(Color.TRANSPARENT);
        channelTapLayer.setOnTouchListener(new View.OnTouchListener() {
            private float startX;
            private float startY;
            private boolean dragging;

            @Override
            public boolean onTouch(View v, android.view.MotionEvent event) {
                boolean portrait =
                        getResources().getConfiguration().orientation
                        == Configuration.ORIENTATION_PORTRAIT;

                switch (event.getAction()) {
                    case android.view.MotionEvent.ACTION_DOWN:
                        startX = event.getX();
                        startY = event.getY();
                        dragging = false;
                        return true;

                    case android.view.MotionEvent.ACTION_MOVE:
                        if (!portrait || channelTransitioning) return true;

                        float dx = event.getX() - startX;
                        float dy = event.getY() - startY;

                        if (Math.abs(dy) > dp(8) &&
                                Math.abs(dy) > Math.abs(dx)) {
                            dragging = true;

                            float height = Math.max(
                                    playerView.getHeight(),
                                    getResources().getDisplayMetrics().heightPixels
                            );

                            float offset = Math.max(
                                    -height,
                                    Math.min(height, dy)
                            );

                            playerView.setTranslationY(offset);

                            if (portraitPanel != null) {
                                portraitPanel.setTranslationY(offset);
                            }

                            handler.removeCallbacks(hideChannelButton);
                            channelButton.setVisibility(View.GONE);
                        }
                        return true;

                    case android.view.MotionEvent.ACTION_UP:
                        float moveY = event.getY() - startY;
                        float moveX = event.getX() - startX;

                        if (dragging) {
                            float threshold = Math.max(
                                    dp(90),
                                    playerView.getHeight() * 0.22f
                            );

                            if (Math.abs(moveY) >= threshold) {
                                finishChannelSwipe(moveY < 0 ? 1 : -1);
                            } else {
                                animateViewsBack();
                            }
                        } else if (Math.abs(moveX) < dp(30) &&
                                   Math.abs(moveY) < dp(30)) {
                            handler.removeCallbacks(hideChannelButton);
                            channelButton.setVisibility(View.VISIBLE);
                            handler.postDelayed(hideChannelButton, 3000);
                        }

                        dragging = false;
                        return true;

                    case android.view.MotionEvent.ACTION_CANCEL:
                        if (dragging) animateViewsBack();
                        dragging = false;
                        return true;
                }
                return true;
            }
        });

        root.addView(channelTapLayer, new FrameLayout.LayoutParams(
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

        loadingSpinner = new android.widget.ProgressBar(
                this, null, android.R.attr.progressBarStyleLarge
        );
        loadingSpinner.setIndeterminate(true);
        loadingSpinner.setIndeterminateTintList(
                android.content.res.ColorStateList.valueOf(Color.RED)
        );
        loadingSpinner.setVisibility(View.GONE);

        FrameLayout.LayoutParams spinnerParams =
                new FrameLayout.LayoutParams(dp(54), dp(54), Gravity.CENTER);
        root.addView(loadingSpinner, spinnerParams);

        channelButton = new Button(this);
        channelButton.setText("KANAL LİSTESİ");
        channelButton.setTextSize(12);
        channelButton.setAllCaps(false);

        channelButton.setTextColor(Color.WHITE);
        channelButton.setPadding(dp(18), dp(8), dp(18), dp(8));

        android.graphics.drawable.GradientDrawable buttonBackground =
            new android.graphics.drawable.GradientDrawable();
        buttonBackground.setColor(0xCC18263A);
        buttonBackground.setCornerRadius(dp(24));
        buttonBackground.setStroke(dp(1), 0x66FFFFFF);

        channelButton.setBackground(buttonBackground);
        channelButton.setElevation(dp(8));
        channelButton.setOnClickListener(v -> showChannelList());
        channelButton.setVisibility(View.GONE);

        FrameLayout.LayoutParams buttonParams =
                new FrameLayout.LayoutParams(
                        -2, dp(46),
                        Gravity.TOP | Gravity.LEFT
                );

        buttonParams.setMargins(dp(16), dp(18), 0, 0);
        root.addView(channelButton, buttonParams);

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

        // Dikey Shorts bilgi ve favori katmanı
        portraitPanel = new LinearLayout(this);
        portraitPanel.setOrientation(LinearLayout.VERTICAL);
        portraitPanel.setPadding(dp(14), dp(10), dp(14), dp(12));
        portraitPanel.setBackgroundColor(0x99000000);

        LinearLayout channelInfo = new LinearLayout(this);
        channelInfo.setOrientation(LinearLayout.HORIZONTAL);
        channelInfo.setGravity(Gravity.CENTER_VERTICAL);

        portraitChannelName = new TextView(this);
        portraitChannelName.setTextColor(Color.WHITE);
        portraitChannelName.setTextSize(16);
        portraitChannelName.setTypeface(null, android.graphics.Typeface.BOLD);
        portraitChannelName.setMaxLines(1);
        portraitChannelName.setEllipsize(android.text.TextUtils.TruncateAt.END);

        LinearLayout.LayoutParams channelNameParams =
                new LinearLayout.LayoutParams(0, -2, 1f);
        channelInfo.addView(portraitChannelName, channelNameParams);

        portraitLiveBadge = new TextView(this);
        portraitLiveBadge.setText("● CANLI");
        portraitLiveBadge.setTextColor(Color.WHITE);
        portraitLiveBadge.setTextSize(11);
        portraitLiveBadge.setTypeface(null, android.graphics.Typeface.BOLD);
        portraitLiveBadge.setPadding(dp(9), dp(5), dp(9), dp(5));
        portraitLiveBadge.setBackgroundColor(0xFFE50914);
        channelInfo.addView(portraitLiveBadge);

        portraitPanel.addView(channelInfo);

        favoriteButton = new Button(this);
        favoriteButton.setTextSize(23);
        favoriteButton.setTextColor(Color.WHITE);
        favoriteButton.setAllCaps(false);
        favoriteButton.setMinWidth(dp(52));
        favoriteButton.setMinimumWidth(dp(52));
        favoriteButton.setPadding(0, 0, 0, 0);
        favoriteButton.setBackgroundColor(0x00000000);
        favoriteButton.setOnClickListener(v -> toggleCurrentFavorite());

        LinearLayout.LayoutParams favoriteParams =
                new LinearLayout.LayoutParams(dp(54), dp(48));
        favoriteParams.topMargin = dp(3);
        portraitPanel.addView(favoriteButton, favoriteParams);

        FrameLayout.LayoutParams portraitParams =
                new FrameLayout.LayoutParams(
                        dp(300), -2,
                        Gravity.BOTTOM | Gravity.LEFT
                );
        portraitParams.setMargins(dp(10), 0, dp(10), dp(24));
        root.addView(portraitPanel, portraitParams);

        updatePortraitOverlay();

        setContentView(root);
    }

    
    private void initializePlayer() {
        player = createManagedPlayer(false);
        playerView.setPlayer(player);
    }

    private ExoPlayer createManagedPlayer(boolean preload) {
        ExoPlayer p = new ExoPlayer.Builder(this).build();

        p.setVolume(preload ? 0f : 1f);

        p.setTrackSelectionParameters(
                p.getTrackSelectionParameters()
                        .buildUpon()
                        .setMaxVideoBitrate(
                                preload ? 1500000 : Integer.MAX_VALUE
                        )
                        .build()
        );

        p.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int state) {
                if (p != player) return;

                if (state == Player.STATE_READY) {
                    status.setVisibility(View.GONE);
                    loadingSpinner.setVisibility(View.GONE);
                } else if (state == Player.STATE_BUFFERING) {
                    loadingSpinner.setVisibility(View.VISIBLE);
                } else if (state == Player.STATE_IDLE) {
                    loadingSpinner.setVisibility(View.GONE);
                }
            }

            @Override
            public void onPlayerError(PlaybackException error) {
                Log.e(TAG, "Oynatıcı hatası: "
                        + error.getErrorCodeName(), error);

                if (p == player) {
                    status.setVisibility(View.GONE);
                    loadingSpinner.setVisibility(View.GONE);
                }
            }
        });

        return p;
    }

    private void prepareChannel(ExoPlayer target, int index,
                               boolean preload) {
        if (index < 0 || index >= channels.size()) return;

        Channel channel = channels.get(index);

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
                    .setMediaId(channel.name == null
                            ? channel.url : channel.name)
                    .build();

            target.stop();
            target.clearMediaItems();

            target.setVolume(preload ? 0f : 1f);

            target.setTrackSelectionParameters(
                    target.getTrackSelectionParameters()
                            .buildUpon()
                            .setMaxVideoBitrate(
                                    preload ? 1500000 : Integer.MAX_VALUE
                            )
                            .build()
            );

            target.setMediaSource(
                    new androidx.media3.exoplayer.source.DefaultMediaSourceFactory(
                            factory
                    ).createMediaSource(item)
            );

            target.prepare();
            target.setPlayWhenReady(!preload);

        } catch (Exception e) {
            Log.e(TAG, "Kanal hazırlanamadı: " + index, e);
        }
    }

    private ExoPlayer obtainStandbyPlayer() {
        if (!standbyPlayers.isEmpty()) {
            return standbyPlayers.remove(standbyPlayers.size() - 1);
        }

        return createManagedPlayer(true);
    }

    private void recyclePlayer(ExoPlayer p) {
        if (p == null || p == player) return;

        p.setPlayWhenReady(false);
        p.stop();
        p.clearMediaItems();
        p.setVolume(0f);

        if (!standbyPlayers.contains(p) && standbyPlayers.size() < 2) {
            standbyPlayers.add(p);
        } else if (!standbyPlayers.contains(p)) {
            p.release();
        }
    }

    private void prepareNeighborChannels() {
        if (channels.size() < 2 || player == null) return;

        int previous = (selectedIndex - 1 + channels.size())
                % channels.size();

        int next = (selectedIndex + 1) % channels.size();

        java.util.HashSet<Integer> wanted = new java.util.HashSet<>();
        wanted.add(previous);
        wanted.add(next);
        wanted.remove(selectedIndex);

        java.util.Iterator<Map.Entry<Integer, ExoPlayer>> iterator =
                preloadedPlayers.entrySet().iterator();

        while (iterator.hasNext()) {
            Map.Entry<Integer, ExoPlayer> entry = iterator.next();

            if (!wanted.contains(entry.getKey())) {
                ExoPlayer old = entry.getValue();
                iterator.remove();
                recyclePlayer(old);
            }
        }

        for (Integer index : wanted) {
            if (!preloadedPlayers.containsKey(index)) {
                ExoPlayer standby = obtainStandbyPlayer();

                preloadedPlayers.put(index, standby);
                prepareChannel(standby, index, true);
            }
        }
    }


    private void animateViewsBack() {
        if (playerView == null) return;

        playerView.animate().cancel();
        playerView.animate()
                .translationY(0f)
                .setDuration(180)
                .start();

        if (portraitPanel != null) {
            portraitPanel.animate().cancel();
            portraitPanel.animate()
                    .translationY(0f)
                    .setDuration(180)
                    .start();
        }
    }

    private void finishChannelSwipe(int direction) {
        if (channels.isEmpty() || channelTransitioning ||
                playerView == null) return;

        channelTransitioning = true;

        final int height = Math.max(
                playerView.getHeight(),
                getResources().getDisplayMetrics().heightPixels
        );

        final float exitY = direction > 0 ? -height : height;
        final float enterY = -exitY;

        playerView.animate().cancel();

        if (portraitPanel != null) {
            portraitPanel.animate().cancel();
        }

        playerView.animate()
                .translationY(exitY)
                .setDuration(150)
                .withEndAction(() -> {
                    selectedIndex += direction;

                    if (selectedIndex >= channels.size()) selectedIndex = 0;
                    if (selectedIndex < 0) selectedIndex = channels.size() - 1;

                    playSelected();

                    playerView.setTranslationY(enterY);

                    if (portraitPanel != null) {
                        portraitPanel.setTranslationY(enterY);
                    }

                    playerView.animate()
                            .translationY(0f)
                            .setDuration(220)
                            .withEndAction(() -> {
                                channelTransitioning = false;
                            })
                            .start();

                    if (portraitPanel != null) {
                        portraitPanel.animate()
                                .translationY(0f)
                                .setDuration(220)
                                .start();
                    }
                })
                .start();

        if (portraitPanel != null) {
            portraitPanel.animate()
                    .translationY(exitY)
                    .setDuration(150)
                    .start();
        }
    }

    
    private void playSelected() {
        if (player == null || selectedIndex < 0 ||
                selectedIndex >= channels.size()) return;

        Channel channel = channels.get(selectedIndex);

        updatePortraitOverlay();

        if (loadingSpinner != null) {
            loadingSpinner.setVisibility(View.VISIBLE);
        }

        if (status != null) {
            status.setVisibility(View.GONE);
        }

        ExoPlayer oldActive = player;
        ExoPlayer readyPlayer = preloadedPlayers.remove(selectedIndex);

        try {
            if (readyPlayer != null) {
                // Hazırlanmış komşu oynatıcıyı aktif hale getir.
                player = readyPlayer;
                playerView.setPlayer(player);

                player.setVolume(1f);
                player.setTrackSelectionParameters(
                        player.getTrackSelectionParameters()
                                .buildUpon()
                                .setMaxVideoBitrate(Integer.MAX_VALUE)
                                .build()
                );

                player.setPlayWhenReady(true);

                recyclePlayer(oldActive);

            } else {
                // Hazır değilse mevcut aktif oynatıcıyla aç.
                prepareChannel(player, selectedIndex, false);
            }

            setTitle(channel.name);
            status.setVisibility(View.GONE);

            // Önceden hazırlanmış oynatıcı READY olmuş olabilir.
            int activeState = player.getPlaybackState();

            if (activeState == Player.STATE_READY) {
                loadingSpinner.setVisibility(View.GONE);
            } else if (activeState == Player.STATE_BUFFERING ||
                       activeState == Player.STATE_IDLE) {
                loadingSpinner.setVisibility(View.VISIBLE);
            }

            prepareNeighborChannels();

        } catch (Exception e) {
            Log.e(TAG, "Kanal başlatılamadı", e);
            loadingSpinner.setVisibility(View.GONE);
        }
    }



    


private boolean isPortraitMode() {
    return getResources().getConfiguration().orientation
            == Configuration.ORIENTATION_PORTRAIT;
}

private boolean isCurrentChannelFavorite() {
    if (selectedIndex < 0 || selectedIndex >= channels.size()) return false;

    String url = channels.get(selectedIndex).url;
    try {
        JSONArray favorites = new JSONArray(
                getSharedPreferences("isa_tv_data", MODE_PRIVATE)
                        .getString("favorites", "[]"));

        for (int i = 0; i < favorites.length(); i++) {
            JSONObject item = favorites.optJSONObject(i);
            if (item != null && url.equals(item.optString("url", ""))) {
                return true;
            }
        }
    } catch (Exception e) {
        Log.e(TAG, "Favoriler okunamadı", e);
    }
    return false;
}

private void updatePortraitOverlay() {
    if (portraitChannelName == null || favoriteButton == null) return;

    boolean portrait = isPortraitMode();

    portraitChannelName.setVisibility(portrait ? View.VISIBLE : View.GONE);
    portraitLiveBadge.setVisibility(portrait ? View.VISIBLE : View.GONE);
    favoriteButton.setVisibility(portrait ? View.VISIBLE : View.GONE);

    if (!portrait) return;

    if (selectedIndex >= 0 && selectedIndex < channels.size()) {
        Channel channel = channels.get(selectedIndex);
        portraitChannelName.setText(
                channel.name == null ? "İSA TV HD" : channel.name);
    }

    favoriteButton.setText(isCurrentChannelFavorite() ? "♥" : "♡");
    favoriteButton.setContentDescription(
            isCurrentChannelFavorite()
                    ? "Favorilerden çıkar"
                    : "Favorilere ekle");
}

private void toggleCurrentFavorite() {
    if (selectedIndex < 0 || selectedIndex >= channels.size()) return;

    Channel channel = channels.get(selectedIndex);
    boolean add = !isCurrentChannelFavorite();

    try {
        JSONObject item = new JSONObject();
        item.put("name", channel.name == null ? "İsimsiz kanal" : channel.name);
        item.put("url", channel.url);
        item.put("group", channel.group == null ? "Genel" : channel.group);
        item.put("logo", channel.logo == null ? "" : channel.logo);

        android.content.SharedPreferences prefs =
                getSharedPreferences("isa_tv_data", MODE_PRIVATE);

        JSONArray old = new JSONArray(prefs.getString("favorites", "[]"));
        JSONArray updated = new JSONArray();

        for (int i = 0; i < old.length(); i++) {
            JSONObject existing = old.optJSONObject(i);
            if (existing == null) continue;

            if (!channel.url.equals(existing.optString("url", ""))) {
                updated.put(existing);
            }
        }

        if (add) updated.put(item);

        prefs.edit().putString("favorites", updated.toString()).apply();
        updatePortraitOverlay();

    } catch (Exception e) {
        Log.e(TAG, "Favori değiştirilemedi", e);
    }
}

private void showChannelList() {
    if (channels.isEmpty()) return;
    if (channelDialog != null && channelDialog.isShowing()) return;

    final Dialog dialog = new Dialog(this);
    channelDialog = dialog;

    final java.util.ArrayList<String> groups = new java.util.ArrayList<>();
    final java.util.LinkedHashMap<String, java.util.ArrayList<Integer>> grouped =
            new java.util.LinkedHashMap<>();

    for (int i = 0; i < channels.size(); i++) {
        Channel c = channels.get(i);
        String g = c.group == null || c.group.trim().isEmpty()
                ? "Genel" : c.group.trim();

        if (!grouped.containsKey(g)) {
            grouped.put(g, new java.util.ArrayList<Integer>());
            groups.add(g);
        }
        grouped.get(g).add(i);
    }

    final int[] groupIndex = {0};

    // Açık kanalın grubunu başlangıç grubu yap.
    if (selectedIndex >= 0 && selectedIndex < channels.size()) {
        String selectedGroup = channels.get(selectedIndex).group;
        if (selectedGroup == null || selectedGroup.trim().isEmpty()) {
            selectedGroup = "Genel";
        } else {
            selectedGroup = selectedGroup.trim();
        }

        int foundGroup = groups.indexOf(selectedGroup);
        if (foundGroup >= 0) groupIndex[0] = foundGroup;
    }

    final java.util.ArrayList<Integer> visibleItems = new java.util.ArrayList<>();

    LinearLayout root = new LinearLayout(this);
    root.setOrientation(LinearLayout.VERTICAL);
    root.setPadding(dp(14), dp(14), dp(14), dp(12));
    root.setBackgroundColor(Color.rgb(17, 21, 29));

    TextView title = new TextView(this);
    title.setText("İSA TV HD  •  KANALLAR");
    title.setTextColor(Color.WHITE);
    title.setTextSize(18);
    title.setTypeface(null, android.graphics.Typeface.BOLD);
    title.setPadding(dp(8), dp(8), dp(8), dp(14));
    root.addView(title);

    LinearLayout groupBar = new LinearLayout(this);
    groupBar.setGravity(Gravity.CENTER);
    groupBar.setOrientation(LinearLayout.HORIZONTAL);
    groupBar.setPadding(dp(4), dp(8), dp(4), dp(8));
    groupBar.setBackgroundColor(0xFF252E3C);

    TextView previous = new TextView(this);
    previous.setText("‹");
    previous.setTextSize(30);
    previous.setTextColor(Color.WHITE);
    previous.setGravity(Gravity.CENTER);
    previous.setMinWidth(dp(48));

    TextView groupName = new TextView(this);
    groupName.setTextColor(Color.WHITE);
    groupName.setTextSize(14);
    groupName.setTypeface(null, android.graphics.Typeface.BOLD);
    groupName.setGravity(Gravity.CENTER);
    groupName.setMaxLines(2);

    TextView next = new TextView(this);
    next.setText("›");
    next.setTextSize(30);
    next.setTextColor(Color.WHITE);
    next.setGravity(Gravity.CENTER);
    next.setMinWidth(dp(48));

    groupBar.addView(previous);
    groupBar.addView(groupName, new LinearLayout.LayoutParams(
            0, dp(48), 1f));
    groupBar.addView(next);
    root.addView(groupBar);

    EditText search = new EditText(this);
    search.setSingleLine(true);
    search.setTextColor(Color.WHITE);
    search.setHintTextColor(0xFFAAAAAA);
    search.setHint("Bu grupta kanal ara...");
    search.setTextSize(14);
    search.setPadding(dp(12), 0, dp(12), 0);
    search.setBackgroundColor(0xFF252E3C);

    LinearLayout.LayoutParams searchParams =
            new LinearLayout.LayoutParams(-1, dp(46));
    searchParams.topMargin = dp(10);
    searchParams.bottomMargin = dp(8);
    root.addView(search, searchParams);

    ListView list = new ListView(this);
    list.setDivider(new android.graphics.drawable.ColorDrawable(0x22FFFFFF));
    list.setDividerHeight(dp(1));
    list.setCacheColorHint(Color.TRANSPARENT);

    TextView count = new TextView(this);
    count.setTextColor(0xFFAAAAAA);
    count.setTextSize(12);
    count.setPadding(dp(8), dp(8), dp(8), dp(8));
    root.addView(count);

    BaseAdapter adapter = new BaseAdapter() {
        @Override public int getCount() {
            return visibleItems.size();
        }

        @Override public Object getItem(int position) {
            return channels.get(visibleItems.get(position));
        }

        @Override public long getItemId(int position) {
            return visibleItems.get(position);
        }

        @Override public View getView(int position, View recycled,
                                      android.view.ViewGroup parent) {
            LinearLayout row;
            ImageView icon;
            LinearLayout texts;
            TextView name;
            TextView subtitle;

            if (recycled instanceof LinearLayout) {
                row = (LinearLayout) recycled;
                icon = (ImageView) row.getChildAt(0);
                texts = (LinearLayout) row.getChildAt(1);
                name = (TextView) texts.getChildAt(0);
                subtitle = (TextView) texts.getChildAt(1);
            } else {
                row = new LinearLayout(PlayerActivity.this);
                row.setGravity(Gravity.CENTER_VERTICAL);
                row.setOrientation(LinearLayout.HORIZONTAL);
                row.setPadding(dp(10), dp(8), dp(10), dp(8));
                row.setMinimumHeight(dp(66));

                icon = new ImageView(PlayerActivity.this);
                icon.setScaleType(ImageView.ScaleType.FIT_CENTER);
                row.addView(icon, new LinearLayout.LayoutParams(dp(46), dp(46)));

                texts = new LinearLayout(PlayerActivity.this);
                texts.setOrientation(LinearLayout.VERTICAL);
                texts.setPadding(dp(12), 0, 0, 0);

                name = new TextView(PlayerActivity.this);
                name.setTextColor(Color.WHITE);
                name.setTextSize(14);
                name.setMaxLines(1);
                name.setEllipsize(android.text.TextUtils.TruncateAt.END);

                subtitle = new TextView(PlayerActivity.this);
                subtitle.setTextColor(0xFFAAAAAA);
                subtitle.setTextSize(11);

                texts.addView(name);
                texts.addView(subtitle);
                row.addView(texts, new LinearLayout.LayoutParams(
                        0, -2, 1f));
            }

            int actual = visibleItems.get(position);
            Channel c = channels.get(actual);

            name.setText((actual == selectedIndex ? "●  " : "")
                    + (c.name == null ? "İsimsiz kanal" : c.name));
            subtitle.setText(actual == selectedIndex ? "ŞU ANDA OYNUYOR" : "CANLI YAYIN");
            row.setBackgroundColor(actual == selectedIndex
                    ? 0xFF303D50 : Color.TRANSPARENT);

            icon.setImageDrawable(null);
            if (c.logo != null && !c.logo.isEmpty()) {
                try {
                    new android.os.AsyncTask<Void, Void, android.graphics.Bitmap>() {
                        @Override
                        protected android.graphics.Bitmap doInBackground(Void... v) {
                            try {
                                return android.graphics.BitmapFactory.decodeStream(
                                        new java.net.URL(c.logo).openStream());
                            } catch (Exception e) {
                                return null;
                            }
                        }
                        @Override
                        protected void onPostExecute(android.graphics.Bitmap bitmap) {
                            if (bitmap != null && icon.getParent() != null) {
                                icon.setImageBitmap(bitmap);
                            }
                        }
                    }.execute();
                } catch (Exception ignored) {}
            }
            return row;
        }
    };

    Runnable updateList = () -> {
        String group = groups.get(groupIndex[0]);
        java.util.ArrayList<Integer> source = grouped.get(group);
        visibleItems.clear();

        String term = search.getText().toString().toLowerCase(
                java.util.Locale.forLanguageTag("tr"));

        for (Integer index : source) {
            String name = channels.get(index).name;
            if (name == null) name = "";
            if (name.toLowerCase(java.util.Locale.forLanguageTag("tr"))
                    .contains(term)) {
                visibleItems.add(index);
            }
        }

        groupName.setText(group + "\n" + source.size() + " KANAL");
        count.setText(visibleItems.size() + " kanal gösteriliyor");
        adapter.notifyDataSetChanged();
    };

    previous.setOnClickListener(v -> {
        groupIndex[0] = (groupIndex[0] - 1 + groups.size()) % groups.size();
        search.setText("");
        updateList.run();
    });

    next.setOnClickListener(v -> {
        groupIndex[0] = (groupIndex[0] + 1) % groups.size();
        search.setText("");
        updateList.run();
    });

    search.addTextChangedListener(new android.text.TextWatcher() {
        @Override public void beforeTextChanged(CharSequence s, int st, int c, int a) {}
        @Override public void onTextChanged(CharSequence s, int st, int before, int count) {
            updateList.run();
        }
        @Override public void afterTextChanged(android.text.Editable e) {}
    });

    list.setAdapter(adapter);
    list.setOnItemClickListener((parent, view, position, id) -> {
        if (position < 0 || position >= visibleItems.size()) return;
        selectedIndex = visibleItems.get(position);
        dialog.dismiss();
        playSelected();
    });

    root.addView(list, new LinearLayout.LayoutParams(-1, 0, 1f));

    TextView close = new TextView(this);
    close.setText("KAPAT");
    close.setTextColor(Color.WHITE);
    close.setGravity(Gravity.CENTER);
    close.setTextSize(13);
    close.setBackgroundColor(0xFF303D50);
    close.setPadding(0, dp(12), 0, dp(12));
    close.setOnClickListener(v -> dialog.dismiss());

    LinearLayout.LayoutParams closeParams =
            new LinearLayout.LayoutParams(-1, dp(46));
    closeParams.topMargin = dp(8);
    root.addView(close, closeParams);

    updateList.run();

    int selectedPosition = visibleItems.indexOf(selectedIndex);
    if (selectedPosition >= 0) {
        list.setSelection(selectedPosition);
    }

    dialog.setContentView(root);
    dialog.setCancelable(true);
    dialog.setOnDismissListener(d -> {
        if (channelDialog == dialog) channelDialog = null;
    });
    dialog.show();

    if (dialog.getWindow() != null) {
        dialog.getWindow().setBackgroundDrawableResource(
                android.R.color.transparent);
        dialog.getWindow().setLayout(
                (int)(getResources().getDisplayMetrics().widthPixels * 0.92f),
                (int)(getResources().getDisplayMetrics().heightPixels * 0.82f));
        dialog.getWindow().addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
        WindowManager.LayoutParams params = dialog.getWindow().getAttributes();
        params.dimAmount = 0.72f;
        dialog.getWindow().setAttributes(params);
    }
}



    private boolean shouldShowTvLogo() {
        return true;
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
    protected void onSaveInstanceState(Bundle outState) {
        outState.putInt("isa_saved_channel_index", selectedIndex);
        super.onSaveInstanceState(outState);
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (player != null) player.pause();
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacksAndMessages(null);

        if (playerView != null) {
            playerView.setPlayer(null);
        }

        java.util.HashSet<ExoPlayer> allPlayers =
                new java.util.HashSet<>();

        if (player != null) allPlayers.add(player);
        allPlayers.addAll(preloadedPlayers.values());
        allPlayers.addAll(standbyPlayers);

        preloadedPlayers.clear();
        standbyPlayers.clear();

        for (ExoPlayer p : allPlayers) {
            try {
                p.release();
            } catch (Exception ignored) {}
        }

        player = null;

        super.onDestroy();
    }

}
