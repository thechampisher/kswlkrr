#!/data/data/com.termux/files/usr/bin/bash
set -e

cd "$HOME/ISA-TV-HD-RECOVERY"

echo "1/4 - Android köprüsü düzeltiliyor..."

python3 - <<'PY'
from pathlib import Path
import re

main = Path("app/src/main/java/com/isatvhd/player/MainActivity.java")
s = main.read_text(encoding="utf-8")

if "public void openPage(String address)" not in s:
    match = re.search(r'(?m)^([ \t]*)public void cachePut\(', s)

    if not match:
        raise SystemExit("MainActivity cachePut metodu bulunamadı.")

    indent = match.group(1)
    annotation = s.rfind("@JavascriptInterface", 0, match.start())

    if annotation < 0:
        annotation = match.start()

    method = (
        indent + "@JavascriptInterface\n"
        + indent + "public void openPage(String address) {\n"
        + indent + "    if (address == null || "
        + "!(address.startsWith(\"https://\") || "
        + "address.startsWith(\"http://\"))) return;\n"
        + indent + "    runOnUiThread(() -> {\n"
        + indent + "        try {\n"
        + indent + "            Intent browser = new Intent("
        + "Intent.ACTION_VIEW, Uri.parse(address));\n"
        + indent + "            MainActivity.this.startActivity(browser);\n"
        + indent + "        } catch (Exception e) {\n"
        + indent + "            Log.e(TAG, \"Kaynak sayfası açılamadı\", e);\n"
        + indent + "        }\n"
        + indent + "    });\n"
        + indent + "}\n\n"
    )

    s = s[:annotation] + method + s[annotation:]

main.write_text(s, encoding="utf-8")

print("MainActivity: openPage köprüsü hazır.")
PY

echo "2/4 - Oynatıcı tam ekran ve kanal listesi düzeltiliyor..."

python3 - <<'PY'
from pathlib import Path
import re

path = Path("app/src/main/java/com/isatvhd/player/PlayerActivity.java")
s = path.read_text(encoding="utf-8")

if "private void applyImmersiveMode()" not in s:
    marker = "    private void createInterface() {"

    if marker not in s:
        raise SystemExit("createInterface metodu bulunamadı.")

    method = """
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

"""
    s = s.replace(marker, method + marker, 1)

if "applyImmersiveMode();" not in s:
    s = s.replace(
        "        super.onCreate(savedInstanceState);\n",
        "        super.onCreate(savedInstanceState);\n"
        "        applyImmersiveMode();\n",
        1
    )

# Kanal listesini modern yarı saydam panele dönüştür.
start = s.find("    private void showChannelList() {")
end = s.find("    private boolean shouldShowTvLogo()", start)

if start < 0 or end < 0:
    raise SystemExit("Kanal listesi metotlarının konumu bulunamadı.")

replacement = r'''
    private void showChannelList() {
        if (channels.isEmpty()) return;

        final android.app.Dialog dialog = new android.app.Dialog(this);

        android.widget.LinearLayout panel =
            new android.widget.LinearLayout(this);
        panel.setOrientation(android.widget.LinearLayout.VERTICAL);
        panel.setPadding(dp(18), dp(16), dp(18), dp(16));

        android.graphics.drawable.GradientDrawable background =
            new android.graphics.drawable.GradientDrawable();
        background.setColor(0xF0141C29);
        background.setCornerRadius(dp(20));
        background.setStroke(dp(1), 0x44FFFFFF);
        panel.setBackground(background);

        TextView heading = new TextView(this);
        heading.setText("KANAL LİSTESİ");
        heading.setTextColor(Color.WHITE);
        heading.setTextSize(18);
        heading.setTypeface(null, android.graphics.Typeface.BOLD);
        heading.setPadding(dp(5), dp(5), dp(5), dp(15));
        panel.addView(heading);

        android.widget.ScrollView scroll =
            new android.widget.ScrollView(this);

        android.widget.LinearLayout list =
            new android.widget.LinearLayout(this);
        list.setOrientation(android.widget.LinearLayout.VERTICAL);

        for (int i = 0; i < channels.size(); i++) {
            final int position = i;
            Channel channel = channels.get(i);

            TextView row = new TextView(this);
            row.setText(
                (i == selectedIndex ? "▶  " : "   ")
                + channel.name
                + (channel.group == null ? "" : "\n" + channel.group)
            );

            row.setTextColor(
                i == selectedIndex ? 0xFFFF6874 : Color.WHITE
            );
            row.setTextSize(14);
            row.setPadding(dp(14), dp(14), dp(14), dp(14));

            android.graphics.drawable.GradientDrawable rowBackground =
                new android.graphics.drawable.GradientDrawable();
            rowBackground.setColor(
                i == selectedIndex ? 0x553E536F : 0x332A3545
            );
            rowBackground.setCornerRadius(dp(11));
            row.setBackground(rowBackground);

            android.widget.LinearLayout.LayoutParams params =
                new android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                );
            params.setMargins(0, 0, 0, dp(7));
            list.addView(row, params);

            row.setOnClickListener(v -> {
                selectedIndex = position;
                dialog.dismiss();
                playSelected();
            });
        }

        scroll.addView(list);

        panel.addView(scroll, new android.widget.LinearLayout.LayoutParams(
            android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
            dp(420)
        ));

        TextView close = new TextView(this);
        close.setText("KAPAT");
        close.setTextColor(Color.WHITE);
        close.setGravity(Gravity.CENTER);
        close.setPadding(dp(12), dp(15), dp(12), dp(8));
        close.setOnClickListener(v -> dialog.dismiss());
        panel.addView(close);

        dialog.setContentView(panel);
        dialog.show();

        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(
                android.R.color.transparent
            );
            dialog.getWindow().setLayout(
                (int)(getResources().getDisplayMetrics().widthPixels * 0.88f),
                -2
            );
        }
    }

'''
s = s[:start] + replacement + s[end:]

# Telefon, tablet ve TV'de logo.
s = re.sub(
    r'    private boolean shouldShowTvLogo\(\) \{.*?\n    \}',
    '    private boolean shouldShowTvLogo() { return true; }',
    s,
    count=1,
    flags=re.S
)

# Kanal listesi butonu görünümü.
old = "        channelButton.setAllCaps(false);\n"
if old in s and "channelButton.setElevation(dp(8));" not in s:
    new = old + """
        channelButton.setTextColor(Color.WHITE);
        channelButton.setPadding(dp(18), dp(8), dp(18), dp(8));

        android.graphics.drawable.GradientDrawable buttonBackground =
            new android.graphics.drawable.GradientDrawable();
        buttonBackground.setColor(0xCC18263A);
        buttonBackground.setCornerRadius(dp(24));
        buttonBackground.setStroke(dp(1), 0x66FFFFFF);

        channelButton.setBackground(buttonBackground);
        channelButton.setElevation(dp(8));
"""
    s = s.replace(old, new, 1)

path.write_text(s, encoding="utf-8")
print("PlayerActivity: tam ekran, logo ve kanal listesi hazır.")
PY

echo "3/4 - JavaScript VOD kart sıralaması kontrol ediliyor..."

python3 - <<'PY'
from pathlib import Path

p = Path("app/src/main/assets/isa-tv-hd/js/isa-sources.js")
s = p.read_text(encoding="utf-8")

s = s.replace(
    "${series.map((item,index) => vodCard(item,'series',index)).join('')}",
    "${series.map(item => vodCard(item,'series',items.indexOf(item))).join('')}"
)

s = s.replace(
    "${films.map((item,index) => vodCard(item,'film',index)).join('')}",
    "${films.map(item => vodCard(item,'film',items.indexOf(item))).join('')}"
)

p.write_text(s, encoding="utf-8")
print("VOD kart sıralaması kontrol edildi.")
PY

echo "4/4 - Kontroller ve APK derlemesi..."

JS="app/src/main/assets/isa-tv-hd/js/isa-sources.js"
MAIN="app/src/main/java/com/isatvhd/player/MainActivity.java"
PLAYER="app/src/main/java/com/isatvhd/player/PlayerActivity.java"

test -s "$JS"
test -s "$MAIN"
test -s "$PLAYER"

if command -v node >/dev/null 2>&1; then
    node --check "$JS"
fi

gradle --no-daemon clean assembleDebug

APK="app/build/outputs/apk/debug/app-debug.apk"

if [ ! -s "$APK" ]; then
    echo "APK oluşturulamadı."
    exit 1
fi

mkdir -p "$HOME/storage/downloads"
cp "$APK" "$HOME/storage/downloads/ISA-TV-HD.apk"

echo
echo "================================"
echo "APK BAŞARIYLA OLUŞTURULDU"
echo "================================"
echo "$HOME/storage/downloads/ISA-TV-HD.apk"
