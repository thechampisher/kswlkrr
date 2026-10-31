package com.isatvhd.player;

import android.app.Activity;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.animation.ValueAnimator;
import android.graphics.Color;
import android.view.Gravity;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.content.Intent;

public class SplashActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().setBackgroundDrawableResource(android.R.color.transparent);
        getWindow().setStatusBarColor(Color.TRANSPARENT);
        getWindow().setNavigationBarColor(Color.TRANSPARENT);

        FrameLayout splash = new FrameLayout(this);
        splash.setBackgroundColor(Color.TRANSPARENT);

        ImageView logo = new ImageView(this);
        logo.setImageResource(R.drawable.logo);
        logo.setScaleType(ImageView.ScaleType.FIT_CENTER);
        logo.setAlpha(0.05f);
        logo.setScaleX(0.86f);
        logo.setScaleY(0.86f);

        float density = getResources().getDisplayMetrics().density;
        logo.setTranslationX(18 * density);

        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(
                (int)(300 * density),
                (int)(200 * density),
                Gravity.CENTER
        );

        splash.addView(logo, params);
        setContentView(splash);

        ValueAnimator animator = ValueAnimator.ofFloat(0f, 1f);
        animator.setDuration(6000);

        animator.addUpdateListener(animation -> {
            float progress = (float) animation.getAnimatedValue();

            // İlk 3 saniyede tamamen görünür ve aydınlık.
            float alpha = 0.05f + Math.min(1f, progress * 2f) * 0.95f;
            logo.setAlpha(alpha);

            // 6 saniye boyunca kesintisiz yakınlaşma.
            float scale = 0.86f + progress * 0.34f;
            logo.setScaleX(scale);
            logo.setScaleY(scale);
        });

        animator.start();

        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            startActivity(new Intent(SplashActivity.this, MainActivity.class));
            overridePendingTransition(0, 0);
            finish();
        }, 6000);
    }
}
