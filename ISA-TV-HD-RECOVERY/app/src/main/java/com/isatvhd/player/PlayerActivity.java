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

            @Override
            public boolean onTouch(View v, android.view.MotionEvent event) {
                switch (event.getAction()) {
                    case android.view.MotionEvent.ACTION_DOWN:
                        startX = event.getX();
                        startY = event.getY();
                        return true;

                    case android.view.MotionEvent.ACTION_UP:
                        float dx = event.getX() - startX;
                        float dy = event.getY() - startY;

                        if (Math.abs(dy) > dp(65) &&
                                Math.abs(dy) > Math.abs(dx)) {
                            handler.removeCallbacks(hideChannelButton);
                            channelButton.setVisibility(View.GONE);

                            if (dy < 0) {
                                changeChannelBySwipe(1);
                            } else {
                                changeChannelBySwipe(-1);
                            }
                        } else if (Math.abs(dx) < dp(30) &&
                                   Math.abs(dy) < dp(30)) {
                            handler.removeCallbacks(hideChannelButton);
                            channelButton.setVisibility(View.VISIBLE);
                            handler.postDelayed(hideChannelButton, 4000);
                        }
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
                    loadingSpinner.setVisibility(View.GONE);
                } else if (state == Player.STATE_BUFFERING) {
                    loadingSpinner.setVisibility(View.VISIBLE);
                } else if (state == Player.STATE_IDLE) {
                    loadingSpinner.setVisibility(View.GONE);
                }
            }

            @Override
            public void onPlayerError(PlaybackException error) {
                Log.e(TAG, "Oynatma hatası: "
                        + error.getErrorCodeName(), error);
                status.setVisibility(View.GONE);
                loadingSpinner.setVisibility(View.GONE);
            }
        });
    }

    private void changeChannelBySwipe(int direction) {
        if (channels.isEmpty()) return;

        selectedIndex += direction;

        if (selectedIndex >= channels.size()) selectedIndex = 0;
        if (selectedIndex < 0) selectedIndex = channels.size() - 1;

        playSelected();
    }

    private void playSelected() {
        if (player == null || selectedIndex < 0 ||
                selectedIndex >= channels.size()) return;

        Channel channel = channels.get(selectedIndex);

        if (loadingSpinner != null) loadingSpinner.setVisibility(View.VISIBLE);
        if (status != null) status.setVisibility(View.GONE);

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

    // Açık pencere varken tekrar oluşturma.
    if (channelDialog != null && channelDialog.isShowing()) return;

    final Dialog dialog = new Dialog(this);
    channelDialog = dialog;

    LinearLayout container = new LinearLayout(this);
    container.setOrientation(LinearLayout.VERTICAL);
    container.setPadding(dp(12), dp(12), dp(12), dp(12));
    container.setBackgroundColor(Color.rgb(20, 20, 20));

    TextView heading = new TextView(this);
    heading.setText("KANAL LİSTESİ  •  " + channels.size() + " KANAL");
    heading.setTextColor(Color.WHITE);
    heading.setTextSize(17);
    heading.setTypeface(null, android.graphics.Typeface.BOLD);
    heading.setPadding(dp(10), dp(10), dp(10), dp(14));
    container.addView(heading);

    ListView list = new ListView(this);
    list.setDivider(new android.graphics.drawable.ColorDrawable(0x33FFFFFF));
    list.setDividerHeight(dp(1));
    list.setCacheColorHint(Color.TRANSPARENT);
    list.setScrollingCacheEnabled(false);
    list.setFastScrollEnabled(true);

    BaseAdapter adapter = new BaseAdapter() {
        @Override
        public int getCount() {
            return channels.size();
        }

        @Override
        public Object getItem(int position) {
            return channels.get(position);
        }

        @Override
        public long getItemId(int position) {
            return position;
        }

        @Override
        public View getView(int position, View convertView,
                            android.view.ViewGroup parent) {

            LinearLayout row;
            TextView name;
            TextView group;

            if (convertView instanceof LinearLayout) {
                row = (LinearLayout) convertView;
                name = (TextView) row.getChildAt(0);
                group = (TextView) row.getChildAt(1);
            } else {
                row = new LinearLayout(PlayerActivity.this);
                row.setOrientation(LinearLayout.VERTICAL);
                row.setPadding(dp(14), dp(11), dp(14), dp(11));
                row.setMinimumHeight(dp(58));

                name = new TextView(PlayerActivity.this);
                name.setTextColor(Color.WHITE);
                name.setTextSize(15);
                name.setMaxLines(1);
                name.setEllipsize(android.text.TextUtils.TruncateAt.END);

                group = new TextView(PlayerActivity.this);
                group.setTextColor(0xFFAAAAAA);
                group.setTextSize(11);
                group.setMaxLines(1);
                group.setEllipsize(android.text.TextUtils.TruncateAt.END);

                row.addView(name);
                row.addView(group);
            }

            Channel channel = channels.get(position);
            name.setText(
                (position == selectedIndex ? "▶  " : "") +
                (channel.name == null ? "İsimsiz kanal" : channel.name)
            );
            group.setText(
                channel.group == null ? "Genel" : channel.group
            );

            row.setBackgroundColor(
                position == selectedIndex
                    ? 0xFF343434
                    : Color.TRANSPARENT
            );

            return row;
        }
    };

    list.setAdapter(adapter);

    list.setOnItemClickListener((parent, view, position, id) -> {
        if (position < 0 || position >= channels.size()) return;

        selectedIndex = position;
        dialog.dismiss();
        playSelected();
    });

    container.addView(
        list,
        new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            0,
            1f
        )
    );

    TextView close = new TextView(this);
    close.setText("KAPAT");
    close.setTextColor(Color.WHITE);
    close.setTextSize(13);
    close.setGravity(Gravity.CENTER);
    close.setPadding(dp(12), dp(13), dp(12), dp(13));
    close.setBackgroundColor(0xFF303030);
    close.setOnClickListener(v -> dialog.dismiss());

    LinearLayout.LayoutParams closeParams =
        new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            dp(46)
        );
    closeParams.topMargin = dp(8);
    container.addView(close, closeParams);

    dialog.setContentView(container);
    dialog.setCancelable(true);

    android.view.Window window = dialog.getWindow();
    if (window != null) {
        window.setBackgroundDrawableResource(
            android.R.color.transparent
        );
        window.addFlags(
            WindowManager.LayoutParams.FLAG_DIM_BEHIND
        );
        WindowManager.LayoutParams params = window.getAttributes();
        params.width = (int) (getResources()
            .getDisplayMetrics().widthPixels * 0.90f);
        params.height = (int) (getResources()
            .getDisplayMetrics().heightPixels * 0.78f);
        params.gravity = Gravity.CENTER;
        params.dimAmount = 0.72f;
        window.setAttributes(params);
    }

    dialog.setOnDismissListener(d -> {
        if (channelDialog == dialog) channelDialog = null;
    });

    dialog.show();

    // Boyutları show() sonrasında uygula.
    if (dialog.getWindow() != null) {
        dialog.getWindow().setLayout(
            (int) (getResources().getDisplayMetrics().widthPixels * 0.90f),
            (int) (getResources().getDisplayMetrics().heightPixels * 0.78f)
        );
    }
}


    private boolean shouldShowTvLogo() { return true; }

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
