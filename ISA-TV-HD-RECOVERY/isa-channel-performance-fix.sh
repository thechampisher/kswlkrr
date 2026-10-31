#!/data/data/com.termux/files/usr/bin/bash
set -e

FILE="app/src/main/java/com/isatvhd/player/PlayerActivity.java"

if [ ! -f "$FILE" ]; then
    echo "PlayerActivity.java bulunamadı."
    exit 1
fi

STAMP=$(date +%Y%m%d-%H%M%S)
cp "$FILE" "$FILE.bak-$STAMP"

python - <<'PY'
from pathlib import Path
import re

p = Path("app/src/main/java/com/isatvhd/player/PlayerActivity.java")
s = p.read_text()

# Gerekli importları ekle.
imports = [
    "import android.app.Dialog;",
    "import android.widget.ListView;",
    "import android.widget.BaseAdapter;",
    "import android.graphics.drawable.GradientDrawable;",
    "import android.widget.LinearLayout;"
]

for imp in imports:
    if imp not in s:
        s = s.replace("import android.app.Activity;", "import android.app.Activity;\n" + imp, 1)

# Dialog alanı.
if "private Dialog channelDialog;" not in s:
    marker = "private Button channelButton;"
    if marker not in s:
        raise SystemExit("channelButton alanı bulunamadı.")
    s = s.replace(marker, marker + "\nprivate Dialog channelDialog;", 1)

# showChannelList metodunu parantez dengesiyle bul ve değiştir.
match = re.search(r'\bprivate\s+void\s+showChannelList\s*\(\s*\)\s*\{', s)
if not match:
    raise SystemExit("showChannelList metodu bulunamadı.")

start = match.start()
brace = s.find("{", match.start())
depth = 0
end = None

for i in range(brace, len(s)):
    if s[i] == "{":
        depth += 1
    elif s[i] == "}":
        depth -= 1
        if depth == 0:
            end = i + 1
            break

if end is None:
    raise SystemExit("showChannelList metodu çözümlenemedi.")

new_method = r'''
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
'''

s = s[:start] + new_method + s[end:]
p.write_text(s)
print("Kanal listesi performans yaması uygulandı.")
PY

echo "Derleme başlıyor..."
gradle --no-daemon clean assembleDebug

mkdir -p ~/storage/downloads
cp app/build/outputs/apk/debug/app-debug.apk \
   ~/storage/downloads/ISA-TV-HD.apk

echo
echo "İşlem tamamlandı."
echo "APK: İndirilenler/ISA-TV-HD.apk"
