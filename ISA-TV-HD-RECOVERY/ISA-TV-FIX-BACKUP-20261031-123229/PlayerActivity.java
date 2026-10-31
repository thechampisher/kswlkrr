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
                (PlayerView.ControllerVisibilityListener) visibility ->
                        channelButton.setVisibility(
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
