from pathlib import Path
import re
import shutil
import time
import sys

ROOT = Path.home() / "ISA-TV-HD-RECOVERY"

JS = ROOT / "app/src/main/assets/isa-tv-hd/js/isa-sources.js"
MAIN = ROOT / "app/src/main/java/com/isatvhd/player/MainActivity.java"
PLAYER = ROOT / "app/src/main/java/com/isatvhd/player/PlayerActivity.java"

for f in (JS, MAIN, PLAYER):
    if not f.exists():
        sys.exit("HATA: Dosya bulunamadı: " + str(f))

js = JS.read_text(encoding="utf-8")
main = MAIN.read_text(encoding="utf-8")
player = PLAYER.read_text(encoding="utf-8")

backup = ROOT / ("ISA-TV-FIX-BACKUP-" + time.strftime("%Y%m%d-%H%M%S"))
backup.mkdir()

for f in (JS, MAIN, PLAYER):
    shutil.copy2(f, backup / f.name)

print("Yedek oluşturuldu:", backup)


# --------------------------------------------------
# 1. JAVASCRIPT: KALICI KAYNAK ÖNBELLEĞİ
# --------------------------------------------------

if "window.__isaCacheDone" not in js:
    marker = "let fetchCounter = 0;"

    if marker not in js:
        sys.exit("HATA: fetchCounter bulunamadı. Dosya değiştirilmedi.")

    cache_code = r"""
let cacheCounter = 0;

window.__isaCacheCallbacks = {};

window.__isaCacheDone = function(id, value, error) {
    const cb = window.__isaCacheCallbacks[id];
    if (!cb) return;

    delete window.__isaCacheCallbacks[id];

    if (error) cb.reject(new Error(error));
    else cb.resolve(value);
};

function nativeCacheGet(key) {
    if (!window.ISATV || !window.ISATV.cacheGet) {
        try {
            return Promise.resolve(
                localStorage.getItem('isa-cache:' + key)
            );
        } catch (e) {
            return Promise.resolve(null);
        }
    }

    return new Promise((resolve, reject) => {
        const id = ++cacheCounter;
        window.__isaCacheCallbacks[id] = {resolve, reject};
        window.ISATV.cacheGet(key, String(id));
    });
}

function nativeCachePut(key, value) {
    if (window.ISATV && window.ISATV.cachePut) {
        window.ISATV.cachePut(key, value);
    } else {
        try {
            localStorage.setItem('isa-cache:' + key, value);
        } catch (e) {}
    }
}
"""
    js = js.replace(marker, marker + "\n" + cache_code, 1)


# getText: önce kayıtlı veriyi kullan, zorunlu yenilemede indir
pattern = r"async function getText\(url\)\s*\{\s*return nativeFetch\(url\);\s*\}"

replacement = r"""
async function getText(url, forceRefresh = false) {
    let cached = null;

    try {
        cached = await nativeCacheGet(url);
    } catch (e) {}

    if (!forceRefresh && cached !== null && cached !== '') {
        return cached;
    }

    try {
        const fresh = await nativeFetch(url);
        nativeCachePut(url, fresh);
        return fresh;
    } catch (e) {
        if (cached !== null && cached !== '') return cached;
        throw e;
    }
}
"""

js, count = re.subn(pattern, replacement, js, count=1)

if count != 1:
    sys.exit("HATA: getText fonksiyonu bulunamadı. Dosya değiştirilmedi.")


# --------------------------------------------------
# 2. JAVASCRIPT: KANALLARI KAPALI GRUPLARDA GÖSTER
# --------------------------------------------------

render_code = r"""
function renderChannels() {
    const grid = document.getElementById('all-channels');
    if (!grid) return;

    const groups = new Map();

    channels.forEach((channel, index) => {
        const group = channel.group || 'Genel';

        if (!groups.has(group)) {
            groups.set(group, []);
        }

        groups.get(group).push({channel, index});
    });

    if (!channels.length) {
        grid.innerHTML = '<p>Henüz kanal bulunamadı.</p>';
        return;
    }

    grid.innerHTML = Array.from(groups.entries()).map(([group, items]) => {
        return `
            <details class="isa-channel-category">
                <summary>${escapeHtml(group)}</summary>
                <div class="channels-grid">
                    ${items.map(({channel, index}) => `
                        <div class="channel-card"
                             data-isa-index="${index}">
                            <div class="channel-thumbnail">
                                ${channel.logo
                                    ? `<img src="${escapeHtml(channel.logo)}"
                                            alt=""
                                            onerror="this.style.display='none'">`
                                    : `<div class="channel-placeholder">
                                            <i class="fas fa-tv"></i>
                                       </div>`
                                }
                                <div class="channel-overlay">
                                    <button class="play-button" type="button">
                                        <i class="fas fa-play"></i>
                                    </button>
                                </div>
                            </div>
                            <div class="channel-info">
                                <h3 class="channel-name">
                                    ${escapeHtml(channel.name)}
                                </h3>
                            </div>
                        </div>
                    `).join('')}
                </div>
            </details>
        `;
    }).join('');

    grid.querySelectorAll('[data-isa-index]').forEach(card => {
        card.addEventListener('click', () => {
            const index = Number(card.dataset.isaIndex);
            play(channels[index]);
        });
    });

    const search = document.getElementById('search-input');

    if (search && !search.dataset.isaBound) {
        search.dataset.isaBound = '1';

        search.addEventListener('input', () => {
            const term = search.value.toLocaleLowerCase('tr');

            grid.querySelectorAll('[data-isa-index]').forEach(card => {
                const channel = channels[
                    Number(card.dataset.isaIndex)
                ];

                const text = (
                    (channel.name || '') + ' ' +
                    (channel.group || '')
                ).toLocaleLowerCase('tr');

                card.style.display = text.includes(term) ? '' : 'none';
            });

            grid.querySelectorAll('.isa-channel-category').forEach(section => {
                const visible = Array.from(
                    section.querySelectorAll('[data-isa-index]')
                ).some(card => card.style.display !== 'none');

                section.style.display = visible ? '' : 'none';

                if (term && visible) section.open = true;
                if (!term) section.open = false;
            });
        });
    }
}
"""

js, count = re.subn(
    r"function renderChannels\(\)\s*\{.*?(?=\nfunction ensureSections)",
    render_code + "\n",
    js,
    count=1,
    flags=re.S
)

if count != 1:
    sys.exit("HATA: renderChannels fonksiyonu bulunamadı.")


# Grup tasarımı
style = r"""
.isa-channel-category {
    margin: 10px 0;
    background: #171717;
    border: 1px solid #303030;
    border-radius: 10px;
    overflow: hidden;
}

.isa-channel-category > summary {
    list-style: none;
    cursor: pointer;
    padding: 17px 18px;
    color: #fff;
    font-size: 16px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.isa-channel-category > summary::-webkit-details-marker {
    display: none;
}

.isa-channel-category > summary:after {
    content: '+';
    font-size: 22px;
    color: #e50914;
}

.isa-channel-category[open] > summary:after {
    content: '−';
}

.isa-channel-category > .channels-grid {
    padding: 12px;
}
"""

if ".isa-channel-category > summary" not in js:
    js = js.replace("</style>", style + "\n</style>", 1)


# --------------------------------------------------
# 3. JAVASCRIPT: KAYNAKLARI ÖNBELLEKTEN OKU
# --------------------------------------------------

js = js.replace(
    "async function loadLiveChannels() {",
    "async function loadLiveChannels(forceRefresh = false) {"
)

js = js.replace(
    "JSON.parse(await getText(LIVE_JSON))",
    "JSON.parse(await getText(LIVE_JSON, forceRefresh))"
)

js = js.replace(
    "const text = await getText(p.url);",
    "const text = await getText(p.url, forceRefresh);"
)

js = js.replace(
    "async function loadUserLists(selectedIndex) {",
    "async function loadUserLists(selectedIndex, forceRefresh = false) {"
)

js = js.replace(
    "item.text = await getText(item.url);",
    "item.text = await getText(item.url, forceRefresh);"
)

js = js.replace(
    "async function loadVOD() {",
    "async function loadVOD(forceRefresh = false) {"
)

js = js.replace(
    "JSON.parse(await getText(VOD_JSON))",
    "JSON.parse(await getText(VOD_JSON, forceRefresh))"
)


# --------------------------------------------------
# 4. JAVASCRIPT: YENİLEME FONKSİYONU
# --------------------------------------------------

refresh_code = r"""
async function refreshAll(forceRefresh = false) {
    const status = document.getElementById('isa-live-status');

    if (status) {
        status.textContent = forceRefresh
            ? 'Kaynaklar güncelleniyor...'
            : 'Kayıtlı kaynaklar yükleniyor...';
    }

    let live = [];

    try {
        live = await loadLiveChannels(forceRefresh);
    } catch (e) {
        console.error('Güneş TV:', e);
    }

    let user = [];

    try {
        user = await loadUserLists(undefined, forceRefresh);
    } catch (e) {
        console.error('Kullanıcı listeleri:', e);
    }

    channels = [...live, ...user];

    renderChannels();
    renderSavedLists();

    if (status) {
        status.textContent =
            live.length + ' Güneş TV kanalı, ' +
            user.length + ' kişisel liste kanalı yüklendi.';
    }

    try {
        await loadVOD(forceRefresh);
    } catch (e) {
        console.error('VOD:', e);

        const vodStatus = document.getElementById('isa-vod-status');

        if (vodStatus) {
            vodStatus.textContent = 'VOD kaynakları yüklenemedi.';
        }
    }
}
"""

js, count = re.subn(
    r"async function refreshAll\(\)\s*\{.*?(?=\nfunction bindUpload)",
    refresh_code + "\n",
    js,
    count=1,
    flags=re.S
)

if count != 1:
    sys.exit("HATA: refreshAll fonksiyonu bulunamadı.")


# Yenile butonu internete çıkarak kaynakları güncellesin
js = js.replace(
    "document.getElementById('isa-refresh').onclick = refreshAll;",
    "document.getElementById('isa-refresh').onclick = () => refreshAll(true);"
)

JS.write_text(js, encoding="utf-8")
print("JavaScript düzenlendi.")


# --------------------------------------------------
# 5. MAINACTIVITY: KANAL KUYRUĞUNU DOSYADAN AKTAR
# --------------------------------------------------

old_queue = r"""intent.putExtra\(\s*"queue_json",\s*queueJson == null \? "\[\]" : queueJson\s*\);\s*intent.putExtra\("selected_index", selectedIndex\);\s*startActivity\(intent\);"""

new_queue = r"""
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
"""

main, count = re.subn(old_queue, new_queue, main, count=1)

if count != 1:
    sys.exit(
        "HATA: MainActivity kanal kuyruğu bölümü eşleşmedi. "
        "Java dosyasına değişiklik kaydedilmedi."
    )


# --------------------------------------------------
# 6. MAINACTIVITY: TELEFONDA KALICI DOSYA ÖNBELLEĞİ
# --------------------------------------------------

if "public void cacheGet(" not in main:

    cache_methods = r"""

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

"""

    # Metotları ISATVBridge sınıfının sonuna ekle
    bridge_start = main.find("public class ISATVBridge")

    if bridge_start < 0:
        sys.exit("HATA: ISATVBridge sınıfı bulunamadı.")

    next_override = main.find(
        "\n    @Override",
        bridge_start
    )

    if next_override < 0:
        sys.exit("HATA: ISATVBridge sonu bulunamadı.")

    close = main.rfind("    }", bridge_start, next_override)

    if close < 0:
        sys.exit("HATA: Bridge kapanış yeri bulunamadı.")

    main = main[:close] + cache_methods + main[close:]


MAIN.write_text(main, encoding="utf-8")
print("MainActivity düzenlendi.")


# --------------------------------------------------
# 7. PLAYERACTIVITY: KUYRUĞU DOSYADAN OKU
# --------------------------------------------------

if 'getStringExtra("queue_file")' not in player:

    # queue_json okunan değişkeni bul
    match = re.search(
        r'String\s+queueJson\s*=\s*getIntent\(\)\.getStringExtra\("queue_json"\)\s*;',
        player
    )

    if not match:
        sys.exit(
            "HATA: PlayerActivity queue_json okuma satırı bulunamadı."
        )

    read_queue = r"""
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
"""

    player = (
        player[:match.start()] +
        read_queue.strip() +
        player[match.end():]
    )


PLAYER.write_text(player, encoding="utf-8")
print("PlayerActivity düzenlendi.")

print("")
print("TÜM PATCH İŞLEMLERİ TAMAMLANDI.")
print("Yedek klasörü:", backup)
print("Değiştirilen dosyalar:")
print(JS)
print(MAIN)
print(PLAYER)
