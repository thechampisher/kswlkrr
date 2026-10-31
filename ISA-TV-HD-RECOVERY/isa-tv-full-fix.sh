#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/ISA-TV-HD-RECOVERY"
cd "$ROOT"

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$HOME/ISA-TV-HD-BACKUP-$STAMP"

mkdir -p "$BACKUP"

echo "1/7 - Mevcut dosyalar yedekleniyor..."

cp -a app/src/main/assets/isa-tv-hd "$BACKUP/"
cp -a app/src/main/java/com/isatvhd/player "$BACKUP/"
cp -a app/src/main/AndroidManifest.xml "$BACKUP/"

JS="app/src/main/assets/isa-tv-hd/js/isa-sources.js"
HTML="app/src/main/assets/isa-tv-hd/index.html"
CSS="app/src/main/assets/isa-tv-hd/css/isa-style.css"
MAIN="app/src/main/java/com/isatvhd/player/MainActivity.java"
PLAYER="app/src/main/java/com/isatvhd/player/PlayerActivity.java"

echo "2/7 - Yeni ana sayfa oluşturuluyor..."

cat > "$HTML" <<'HTML'
<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#090b10">
<title>İSA TV HD</title>
<link rel="stylesheet" href="css/isa-style.css">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body class="homepage">

<img class="isa-tv-brand-mark" src="assets/logo.png" alt="İSA TV HD">

<header class="isa-header">
    <div class="isa-header-title">
        <span class="isa-live-dot"></span>
        <strong>İSA TV HD</strong>
    </div>
    <button id="isa-refresh" class="isa-refresh">
        <i class="fas fa-rotate"></i>
        <span>Yenile</span>
    </button>
</header>

<main class="isa-main">

    <section id="isa-live-panel" class="isa-panel active">
        <div class="isa-section-heading">
            <div>
                <span class="isa-eyebrow">CANLI YAYIN</span>
                <h1>Canlı TV</h1>
                <p id="isa-live-status">Kanallar yükleniyor...</p>
            </div>
        </div>

        <div class="isa-source-section">
            <h2><i class="fas fa-list"></i> Kişisel yayın listelerim</h2>

            <div class="isa-input-row">
                <input id="isa-list-name" placeholder="Liste adı">
                <input id="isa-list-url" type="url" placeholder="M3U / M3U8 URL">
                <button id="isa-add-url" class="isa-action">
                    <i class="fas fa-plus"></i> Ekle
                </button>
            </div>

            <div class="isa-file-row">
                <label for="isa-m3u-file" class="isa-file-button">
                    <i class="fas fa-folder-open"></i>
                    Cihazdan M3U dosyası seç
                </label>
                <input id="isa-m3u-file" type="file" accept=".m3u,.m3u8,.txt">
                <span id="isa-upload-status" aria-live="polite"></span>
            </div>

            <div id="isa-saved-lists"></div>
        </div>

        <div class="isa-channel-heading">
            <h2><i class="fas fa-satellite-dish"></i> Kanallar</h2>
            <input id="search-input" type="search" placeholder="Kanal ara...">
        </div>

        <div id="all-channels">
            <p class="isa-loading">Kanallar hazırlanıyor...</p>
        </div>
    </section>

    <section id="isa-vod-panel" class="isa-panel">
        <div class="isa-section-heading">
            <div>
                <span class="isa-eyebrow">FİLM VE DİZİ</span>
                <h1>İSA Flix</h1>
                <p id="isa-vod-status">VOD kaynakları yükleniyor...</p>
            </div>
        </div>

        <div id="isa-vod-grid" class="isa-provider-grid"></div>
        <div id="isa-vod-items"></div>
    </section>

</main>

<nav class="isa-bottom-nav">
    <button class="isa-tab active" data-tab="isa-live-panel">
        <i class="fas fa-tv"></i>
        <span>Canlı TV</span>
    </button>
    <button class="isa-tab" data-tab="isa-vod-panel">
        <i class="fas fa-film"></i>
        <span>İSA Flix</span>
    </button>
</nav>

<script src="js/isa-sources.js"></script>
<script src="js/tr-translation.js"></script>
</body>
</html>
HTML

echo "3/7 - Yeni tasarım oluşturuluyor..."

cat > "$CSS" <<'CSS'
:root {
    color-scheme: dark;
    --bg:#090b10;
    --panel:#111722;
    --card:#171f2d;
    --line:rgba(255,255,255,.09);
    --text:#f5f7fb;
    --muted:#9aa7b8;
    --red:#e63946;
    --blue:#243b64;
}

* {
    box-sizing:border-box;
}

html,body {
    margin:0;
    min-height:100%;
    width:100%;
    background:var(--bg);
    color:var(--text);
    font-family:Arial,Helvetica,sans-serif;
}

body {
    padding-bottom:90px;
    overflow-x:hidden;
}

button,input {
    font:inherit;
}

button {
    cursor:pointer;
}

.isa-tv-brand-mark {
    display:block !important;
    position:fixed !important;
    z-index:10000 !important;
    top:12px !important;
    right:12px !important;
    left:auto !important;
    bottom:auto !important;
    width:76px !important;
    height:54px !important;
    object-fit:contain !important;
    padding:4px !important;
    border-radius:10px !important;
    background:rgba(10,13,20,.82) !important;
    border:1px solid var(--line) !important;
    pointer-events:none !important;
}

.isa-header {
    min-height:76px;
    display:flex;
    align-items:center;
    justify-content:space-between;
    padding:12px 110px 12px 22px;
    border-bottom:1px solid var(--line);
    background:#0c1018;
}

.isa-header-title {
    display:flex;
    align-items:center;
    gap:12px;
    font-size:20px;
    letter-spacing:.5px;
}

.isa-live-dot {
    width:10px;
    height:10px;
    border-radius:50%;
    background:#e63946;
    box-shadow:0 0 14px #e63946;
}

.isa-refresh,.isa-action {
    color:white;
    background:linear-gradient(135deg,#e63946,#a91628);
    border:0;
    border-radius:10px;
    padding:11px 15px;
    font-weight:700;
}

.isa-main {
    width:min(1500px,100%);
    margin:auto;
    padding:20px clamp(12px,3vw,35px);
}

.isa-panel {
    display:none;
    animation:isaFade .2s ease;
}

.isa-panel.active {
    display:block;
}

@keyframes isaFade {
    from {opacity:.5;transform:translateY(5px)}
    to {opacity:1;transform:translateY(0)}
}

.isa-section-heading {
    padding:15px 0 20px;
}

.isa-eyebrow {
    color:#e63946;
    font-size:11px;
    font-weight:800;
    letter-spacing:2px;
}

.isa-section-heading h1 {
    font-size:clamp(27px,4vw,40px);
    margin:8px 0;
}

.isa-section-heading p {
    color:var(--muted);
    margin:0;
}

.isa-source-section {
    background:var(--panel);
    border:1px solid var(--line);
    padding:18px;
    border-radius:16px;
    margin-bottom:25px;
}

.isa-source-section h2 {
    font-size:17px;
    margin:0 0 15px;
}

.isa-input-row {
    display:grid;
    grid-template-columns:1fr 2fr auto;
    gap:9px;
}

.isa-input-row input,
#search-input {
    min-width:0;
    width:100%;
    background:#080d15;
    border:1px solid var(--line);
    border-radius:10px;
    padding:13px;
    color:white;
    outline:none;
}

.isa-input-row input:focus,
#search-input:focus {
    border-color:#e63946;
}

.isa-file-row {
    display:flex;
    align-items:center;
    flex-wrap:wrap;
    gap:12px;
    margin-top:15px;
}

#isa-m3u-file {
    display:none;
}

.isa-file-button {
    display:inline-flex;
    align-items:center;
    gap:9px;
    padding:11px 14px;
    border:1px solid var(--line);
    border-radius:10px;
    background:#202a3a;
    cursor:pointer;
}

#isa-upload-status {
    color:var(--muted);
    font-size:13px;
}

.isa-list-row {
    display:flex;
    align-items:center;
    justify-content:space-between;
    gap:10px;
    padding:11px;
    margin-top:9px;
    background:#0b111b;
    border:1px solid var(--line);
    border-radius:10px;
}

.isa-list-actions {
    display:flex;
    gap:7px;
}

.isa-list-actions button {
    border:1px solid var(--line);
    background:#202b3c;
    color:white;
    padding:8px 10px;
    border-radius:8px;
}

.isa-list-actions .delete {
    background:#5a1b27;
}

.isa-channel-heading {
    display:flex;
    justify-content:space-between;
    align-items:center;
    gap:15px;
    margin:20px 0;
}

.isa-channel-heading h2 {
    font-size:21px;
}

#search-input {
    max-width:300px;
}

.isa-channel-category {
    margin:12px 0;
    border:1px solid var(--line);
    border-radius:13px;
    overflow:hidden;
    background:var(--panel);
}

.isa-channel-category summary {
    padding:17px;
    font-weight:700;
    cursor:pointer;
    list-style:none;
    background:#172131;
}

.isa-channel-category summary::-webkit-details-marker {
    display:none;
}

.isa-channel-category summary:after {
    content:"+";
    float:right;
    color:#e63946;
    font-size:20px;
}

.isa-channel-category[open] summary:after {
    content:"−";
}

.channels-grid {
    display:grid;
    grid-template-columns:repeat(auto-fill,minmax(135px,1fr));
    gap:12px;
    padding:14px;
}

.channel-card {
    min-width:0;
    padding:13px 8px;
    display:flex;
    flex-direction:column;
    align-items:center;
    justify-content:center;
    gap:10px;
    background:var(--card);
    border:1px solid var(--line);
    border-radius:12px;
    cursor:pointer;
    text-align:center;
    transition:.15s;
}

.channel-card:active {
    transform:scale(.97);
}

.channel-thumbnail {
    height:66px;
    width:100%;
    display:grid;
    place-items:center;
}

.channel-thumbnail img {
    max-width:90%;
    max-height:62px;
    object-fit:contain;
}

.channel-placeholder {
    font-size:28px;
    color:#8494aa;
}

.channel-name {
    font-size:13px;
    font-weight:700;
    overflow-wrap:anywhere;
}

.isa-provider-grid {
    display:grid;
    grid-template-columns:repeat(auto-fill,minmax(145px,1fr));
    gap:14px;
}

.isa-provider-card {
    display:flex;
    flex-direction:column;
    gap:9px;
    align-items:center;
    min-width:0;
    min-height:155px;
    padding:13px;
    color:white;
    background:var(--card);
    border:1px solid var(--line);
    border-radius:13px;
    text-align:center;
}

.isa-provider-card img {
    width:100%;
    height:115px;
    object-fit:contain;
    border-radius:8px;
}

.isa-provider-card strong {
    overflow-wrap:anywhere;
}

.isa-provider-card small {
    color:var(--muted);
}

#isa-vod-items {
    margin-top:22px;
}

.isa-vod-toolbar {
    display:flex;
    align-items:center;
    gap:12px;
    margin:18px 0;
}

.isa-back {
    background:#26364c;
    border:1px solid var(--line);
    color:white;
    border-radius:9px;
    padding:10px 15px;
}

.isa-vod-note {
    color:var(--muted);
    padding:15px;
    line-height:1.6;
    background:var(--panel);
    border-radius:12px;
}

.isa-bottom-nav {
    position:fixed;
    z-index:9000;
    bottom:0;
    left:0;
    right:0;
    display:flex;
    justify-content:center;
    gap:10px;
    padding:10px 14px calc(10px + env(safe-area-inset-bottom));
    background:rgba(10,14,22,.96);
    border-top:1px solid var(--line);
    backdrop-filter:blur(15px);
}

.isa-tab {
    flex:1;
    max-width:260px;
    min-height:52px;
    display:flex;
    align-items:center;
    justify-content:center;
    gap:10px;
    border:1px solid transparent;
    border-radius:12px;
    background:transparent;
    color:var(--muted);
    font-weight:700;
}

.isa-tab.active {
    color:white;
    background:#26364c;
    border-color:#3d5576;
}

.isa-tab.active i {
    color:#ff5260;
}

.isa-loading {
    color:var(--muted);
    padding:20px;
}

@media(max-width:650px) {
    .isa-header {
        min-height:68px;
        padding:10px 92px 10px 13px;
    }

    .isa-header-title {
        font-size:17px;
    }

    .isa-refresh {
        padding:10px;
    }

    .isa-refresh span {
        display:none;
    }

    .isa-input-row {
        grid-template-columns:1fr;
    }

    .isa-channel-heading {
        align-items:stretch;
        flex-direction:column;
    }

    #search-input {
        max-width:none;
    }

    .channels-grid {
        grid-template-columns:repeat(2,minmax(0,1fr));
    }

    .isa-provider-grid {
        grid-template-columns:repeat(2,minmax(0,1fr));
    }

    .isa-list-row {
        align-items:flex-start;
        flex-direction:column;
    }

    .isa-tv-brand-mark {
        width:70px !important;
        height:50px !important;
        top:8px !important;
        right:8px !important;
    }
}

@media(min-width:900px) and (orientation:landscape) {
    .isa-tv-brand-mark {
        width:125px !important;
        height:86px !important;
        top:16px !important;
        right:22px !important;
    }

    .isa-main {
        padding-right:160px;
    }
}
CSS

echo "4/7 - Canlı TV ve VOD motoru yazılıyor..."

cat > "$JS" <<'JS'
(function () {
'use strict';

const LIVE_JSON =
'https://raw.githubusercontent.com/GeceHub/gunestv/main/live2.json';

const VOD_JSON =
'https://raw.githubusercontent.com/GeceHub/gunestv/main/vod2.json';

const STORAGE_KEY = 'isa-tv-playlists-v3';

let channels = [];
let playlists = [];
let vodProviders = [];
let fetchCounter = 0;
let cacheCounter = 0;
let currentProvider = null;

window.__isaCacheCallbacks = {};
window.__isaFetchCallbacks = {};

window.__isaCacheDone = function(id,value,error) {
    const cb = window.__isaCacheCallbacks[id];
    if (!cb) return;
    delete window.__isaCacheCallbacks[id];
    if (error) cb.reject(new Error(error));
    else cb.resolve(value);
};

window.__isaFetchDone = function(id,value,error) {
    const cb = window.__isaFetchCallbacks[id];
    if (!cb) return;
    delete window.__isaFetchCallbacks[id];
    if (error) cb.reject(new Error(error));
    else cb.resolve(value);
};

function nativeCacheGet(key) {
    if (!window.ISATV || !window.ISATV.cacheGet) {
        try {
            return Promise.resolve(localStorage.getItem('isa-cache:'+key));
        } catch(e) {
            return Promise.resolve(null);
        }
    }

    return new Promise((resolve,reject) => {
        const id = ++cacheCounter;
        window.__isaCacheCallbacks[id] = {resolve,reject};
        window.ISATV.cacheGet(key,String(id));
    });
}

function nativeCachePut(key,value) {
    if (window.ISATV && window.ISATV.cachePut) {
        window.ISATV.cachePut(key,value);
    } else {
        try {
            localStorage.setItem('isa-cache:'+key,value);
        } catch(e) {}
    }
}

function nativeFetch(url) {
    if (!window.ISATV || !window.ISATV.fetchText) {
        return fetch(url).then(response => {
            if (!response.ok) throw new Error('HTTP '+response.status);
            return response.text();
        });
    }

    return new Promise((resolve,reject) => {
        const id = ++fetchCounter;
        window.__isaFetchCallbacks[id] = {resolve,reject};
        window.ISATV.fetchText(url,String(id));
    });
}

async function getText(url,forceRefresh=false) {
    let cached = null;

    try {
        cached = await nativeCacheGet(url);
    } catch(e) {}

    if (!forceRefresh && cached) return cached;

    try {
        const fresh = await nativeFetch(url);
        nativeCachePut(url,fresh);
        return fresh;
    } catch(e) {
        if (cached) return cached;
        throw e;
    }
}

function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g,c => ({
        '&':'&amp;',
        '<':'&lt;',
        '>':'&gt;',
        '"':'&quot;',
        "'":'&#39;'
    })[c]);
}

function loadSaved() {
    try {
        const saved = JSON.parse(localStorage.getItem(STORAGE_KEY)||'[]');
        playlists = Array.isArray(saved) ? saved : [];
    } catch(e) {
        playlists = [];
    }
}

function saveLists() {
    try {
        localStorage.setItem(STORAGE_KEY,JSON.stringify(playlists));
    } catch(e) {
        console.warn('Liste kaydedilemedi',e);
    }
}

function isHttp(url) {
    return /^https?:\/\//i.test(String(url||''));
}

function isDirectMedia(url) {
    if (!isHttp(url)) return false;

    try {
        const path = new URL(url).pathname.toLowerCase();
        return /\.(m3u8|mp4|mpd|mp3|m4a|aac|ts|mkv|webm|m4v|mov|ogg|flv)$/i.test(path);
    } catch(e) {
        return false;
    }
}

function parseM3U(text,prefix) {
    const lines = String(text||'').replace(/^\uFEFF/,'').split(/\r?\n/);
    const result = [];
    let current = null;
    let headers = {};

    for (const raw of lines) {
        const line = raw.trim();
        if (!line) continue;

        if (line.startsWith('#EXTINF:')) {
            const comma = line.lastIndexOf(',');
            const name = comma >= 0 ? line.slice(comma+1).trim() : 'İsimsiz yayın';
            const group = (line.match(/group-title="([^"]*)"/i)||[])[1] || 'Genel';
            const logo = (line.match(/tvg-logo="([^"]*)"/i)||[])[1] || '';

            current = {
                name,
                group,
                logo,
                url:'',
                headers:{},
                id:prefix+'-'+result.length
            };
            headers = {};
        } else if (line.startsWith('#EXTVLCOPT:') && current) {
            const option = line.substring(11);
            const index = option.indexOf('=');

            if (index > 0) {
                const key = option.substring(0,index).toLowerCase();
                const value = option.substring(index+1);

                if (key === 'http-user-agent') headers['User-Agent'] = value;
                if (key === 'http-referrer' || key === 'http-referer') headers['Referer'] = value;
                if (key === 'http-origin') headers['Origin'] = value;
            }
        } else if (line.startsWith('#EXTHTTP:') && current) {
            try {
                const parsed = JSON.parse(line.substring(9));
                Object.assign(headers,parsed);
            } catch(e) {}
        } else if (current && !line.startsWith('#') && isHttp(line)) {
            current.url = line;
            current.headers = {...headers};
            result.push(current);
            current = null;
            headers = {};
        }
    }

    return result;
}

function play(channel,queue=channels,index=-1) {
    if (!channel || !isHttp(channel.url)) return;

    if (window.ISATV && window.ISATV.play) {
        window.ISATV.play(
            channel.name || 'İSA TV HD',
            channel.url,
            JSON.stringify(channel.headers||{}),
            JSON.stringify(queue||[channel]),
            index < 0 ? Math.max(0,(queue||[]).indexOf(channel)) : index
        );
        return;
    }

    const query = new URLSearchParams({
        stream:channel.url,
        name:channel.name||'İSA TV HD',
        group:channel.group||'',
        logo:channel.logo||''
    });

    location.href = './player.html?'+query.toString();
}

function openPage(url) {
    if (!isHttp(url)) return;

    if (window.ISATV && window.ISATV.openPage) {
        window.ISATV.openPage(url);
        return;
    }

    window.open(url,'_blank','noopener');
}

function renderChannels() {
    const grid = document.getElementById('all-channels');
    if (!grid) return;

    if (!channels.length) {
        grid.innerHTML = '<p class="isa-loading">Henüz kanal bulunamadı.</p>';
        return;
    }

    const groups = new Map();

    channels.forEach((channel,index) => {
        const group = channel.group || 'Genel';
        if (!groups.has(group)) groups.set(group,[]);
        groups.get(group).push({channel,index});
    });

    grid.innerHTML = Array.from(groups.entries()).map(([group,items]) => `
        <details class="isa-channel-category">
            <summary>${esc(group)} <small>(${items.length})</small></summary>
            <div class="channels-grid">
                ${items.map(({channel,index}) => `
                    <div class="channel-card" data-isa-index="${index}">
                        <div class="channel-thumbnail">
                            ${channel.logo
                                ? `<img src="${esc(channel.logo)}" alt="" onerror="this.style.display='none'">`
                                : '<div class="channel-placeholder"><i class="fas fa-tv"></i></div>'}
                        </div>
                        <div class="channel-name">${esc(channel.name)}</div>
                    </div>
                `).join('')}
            </div>
        </details>
    `).join('');

    grid.querySelectorAll('[data-isa-index]').forEach(card => {
        card.addEventListener('click',() => {
            const index = Number(card.dataset.isaIndex);
            play(channels[index],channels,index);
        });
    });

    const search = document.getElementById('search-input');

    if (search && !search.dataset.bound) {
        search.dataset.bound = '1';
        search.addEventListener('input',() => {
            const term = search.value.toLocaleLowerCase('tr');

            grid.querySelectorAll('[data-isa-index]').forEach(card => {
                const channel = channels[Number(card.dataset.isaIndex)];
                const value = (channel.name+' '+channel.group).toLocaleLowerCase('tr');
                card.style.display = value.includes(term) ? '' : 'none';
            });

            grid.querySelectorAll('details').forEach(section => {
                const visible = Array.from(section.querySelectorAll('[data-isa-index]'))
                    .some(card => card.style.display !== 'none');

                section.style.display = visible ? '' : 'none';
                if (term && visible) section.open = true;
                if (!term) section.open = false;
            });
        });
    }
}

function renderSavedLists() {
    const box = document.getElementById('isa-saved-lists');
    if (!box) return;

    box.innerHTML = playlists.length ? playlists.map((item,index) => `
        <div class="isa-list-row">
            <span>
                <strong>${esc(item.name)}</strong>
                <small>${item.type === 'url' ? ' • İnternet listesi' : ' • Yerel dosya'}</small>
                ${item.lastCount != null ? `<small> • ${item.lastCount} kanal</small>` : ''}
                ${item.error ? `<small> • ${esc(item.error)}</small>` : ''}
            </span>
            <span class="isa-list-actions">
                <button data-refresh-list="${index}"><i class="fas fa-rotate"></i></button>
                <button class="delete" data-delete-list="${index}"><i class="fas fa-trash"></i></button>
            </span>
        </div>
    `).join('') : '<p class="isa-vod-note">Henüz kişisel liste eklenmedi.</p>';

    box.querySelectorAll('[data-refresh-list]').forEach(button => {
        button.onclick = async () => {
            await refreshAll(false);
            document.getElementById('isa-upload-status').textContent = 'Listeler yeniden yüklendi.';
        };
    });

    box.querySelectorAll('[data-delete-list]').forEach(button => {
        button.onclick = async () => {
            const index = Number(button.dataset.deleteList);
            playlists.splice(index,1);
            saveLists();
            await refreshAll(false);
        };
    });
}

async function loadLiveChannels(forceRefresh=false) {
    const data = JSON.parse(await getText(LIVE_JSON,forceRefresh));
    if (!Array.isArray(data)) throw new Error('live2.json biçimi geçersiz');

    const results = await Promise.all(data.filter(item => item.url).map(async (item,index) => {
        try {
            const text = await getText(item.url,forceRefresh);
            return parseM3U(text,'gunes-'+index).map(channel => ({
                ...channel,
                group:(item.name||'Güneş TV')+' / '+(channel.group||'Genel'),
                source:item.name||'Güneş TV'
            }));
        } catch(error) {
            console.warn('Güneş TV paketi yüklenemedi',item.name,error);
            return [];
        }
    }));

    return results.flat();
}

async function loadUserLists(forceRefresh=false) {
    const result = [];

    for (let index=0; index<playlists.length; index++) {
        const item = playlists[index];

        try {
            if (item.type === 'url') {
                item.text = await getText(item.url,forceRefresh);
            }

            if (!item.text || (!item.text.includes('#EXTM3U') && !item.text.includes('#EXTINF:'))) {
                throw new Error('Geçerli M3U içeriği bulunamadı.');
            }

            const parsed = parseM3U(item.text,'user-'+index).map(channel => ({
                ...channel,
                group:(item.name||'Kişisel liste')+' / '+(channel.group||'Genel')
            }));

            item.lastCount = parsed.length;
            item.error = '';
            result.push(...parsed);
        } catch(error) {
            item.error = error.message;
            console.warn(item.name,error);
        }
    }

    saveLists();
    return result;
}

function providerName(provider) {
    return provider.name || provider.title || provider.provider || 'VOD Kaynağı';
}

async function loadVOD(forceRefresh=false) {
    const data = JSON.parse(await getText(VOD_JSON,forceRefresh));
    if (!Array.isArray(data)) throw new Error('vod2.json biçimi geçersiz');

    vodProviders = data;

    const grid = document.getElementById('isa-vod-grid');
    grid.innerHTML = data.map((provider,index) => `
        <button class="isa-provider-card" data-provider="${index}">
            ${provider.poster ? `<img src="${esc(provider.poster)}" alt="" onerror="this.style.display='none'">` : '<i class="fas fa-photo-film" style="font-size:40px;padding:25px"></i>'}
            <strong>${esc(providerName(provider))}</strong>
            <small>${esc(provider.description||'Film ve dizi içerikleri')}</small>
        </button>
    `).join('');

    grid.querySelectorAll('[data-provider]').forEach(button => {
        button.onclick = () => openVODProvider(vodProviders[Number(button.dataset.provider)]);
    });

    document.getElementById('isa-vod-status').textContent =
        data.length+' VOD kaynağı hazır.';
}

/*
 * JSON nesnelerini düzleştirmeden korur.
 * Dizi nesnesinin episodes/seasons yapısı kaybolmaz.
 */
function normalizeVOD(data,result=[]) {
    if (Array.isArray(data)) {
        data.forEach(item => normalizeVOD(item,result));
        return result;
    }

    if (!data || typeof data !== 'object') return result;

    const title = data.title || data.name || data.baslik ||
                  data.titleName || data.filename;

    const url = data.url || data.link || data.file ||
                data.stream || data.playUrl || data.video;

    const hasChildren =
        Array.isArray(data.episodes) ||
        Array.isArray(data.seasons) ||
        Array.isArray(data.items);

    if (title && (url || hasChildren)) {
        result.push({
            type:String(data.type||'').toLowerCase(),
            name:String(title),
            title:String(title),
            url:url||'',
            videoUrl:data.videoUrl||'',
            logo:data.poster||data.image||data.cover||data.thumbnail||'',
            poster:data.poster||data.image||data.cover||'',
            description:data.description||'',
            category:data.category||'',
            genres:Array.isArray(data.genres) ? data.genres : [],
            year:data.year||'',
            platform:data.platform||'',
            episodes:Array.isArray(data.episodes) ? data.episodes : [],
            seasons:Array.isArray(data.seasons) ? data.seasons : [],
            items:Array.isArray(data.items) ? data.items : [],
            raw:data
        });
        return result;
    }

    Object.values(data).forEach(value => {
        if (value && typeof value === 'object') normalizeVOD(value,result);
    });

    return result;
}

function itemIsSeries(item) {
    return item.episodes.length > 0 ||
           item.seasons.length > 0 ||
           item.type.includes('dizi') ||
           item.type.includes('series');
}

function renderVODItems(items,provider) {
    const area = document.getElementById('isa-vod-items');

    const films = items.filter(item => !itemIsSeries(item));
    const series = items.filter(item => itemIsSeries(item));

    area.innerHTML = `
        <div class="isa-vod-toolbar">
            <button class="isa-back" id="isa-vod-back">
                <i class="fas fa-arrow-left"></i> Kaynaklar
            </button>
            <h2>${esc(providerName(provider))}</h2>
        </div>

        ${series.length ? '<h3>Diziler</h3>' : ''}
        <div class="isa-provider-grid">
            ${series.map((item,index) => vodCard(item,'series',index)).join('')}
        </div>

        ${films.length ? '<h3 style="margin-top:25px">Filmler ve diğer içerikler</h3>' : ''}
        <div class="isa-provider-grid">
            ${films.map((item,index) => vodCard(item,'film',index)).join('')}
        </div>

        ${!items.length ? '<p class="isa-vod-note">Bu kaynakta gösterilebilir içerik bulunamadı.</p>' : ''}
    `;

    document.getElementById('isa-vod-back').onclick = () => {
        area.innerHTML = '';
        document.getElementById('isa-vod-grid').scrollIntoView({behavior:'smooth'});
    };

    area.querySelectorAll('[data-vod-kind]').forEach(button => {
        button.onclick = () => {
            const item = items[Number(button.dataset.vod-index)];
            if (button.dataset.vod-kind === 'series') {
                showSeries(item,provider);
            } else {
                openVODItem(item);
            }
        };
    });
}

function vodCard(item,kind,index) {
    return `
        <button class="isa-provider-card" data-vod-kind="${kind}" data-vod-index="${index}">
            ${item.logo ? `<img src="${esc(item.logo)}" alt="" onerror="this.style.display='none'">` : '<i class="fas fa-film" style="font-size:35px;padding:25px"></i>'}
            <strong>${esc(item.name)}</strong>
            <small>${esc(item.year)} ${esc(item.category)}</small>
        </button>
    `;
}

async function openVODProvider(provider) {
    const area = document.getElementById('isa-vod-items');
    currentProvider = provider;
    area.innerHTML = '<p class="isa-loading">İçerikler yükleniyor...</p>';

    try {
        const text = await getText(provider.url);
        let items;

        if (text.trim().startsWith('#EXTM3U') || text.includes('#EXTINF:')) {
            items = parseM3U(text,'vod').map(item => ({
                ...item,
                title:item.name,
                logo:item.logo,
                episodes:[],
                seasons:[],
                type:'film'
            }));
        } else {
            items = normalizeVOD(JSON.parse(text));
        }

        renderVODItems(items,provider);
    } catch(error) {
        area.innerHTML = `
            <div class="isa-vod-toolbar">
                <button class="isa-back" onclick="document.getElementById('isa-vod-items').innerHTML=''">
                    <i class="fas fa-arrow-left"></i> Geri
                </button>
                <h2>${esc(providerName(provider))}</h2>
            </div>
            <p class="isa-vod-note">Kaynak okunamadı: ${esc(error.message)}</p>
        `;
    }
}

function seasonNumber(item) {
    if (item.season != null) return Number(item.season);
    if (item.season_number != null) return Number(item.season_number);

    const title = item.title||item.name||'';
    const match = title.match(/(?:season|sezon|s)\s*0*(\d+)/i);
    return match ? Number(match[1]) : 1;
}

function showSeries(series,provider) {
    const area = document.getElementById('isa-vod-items');
    let episodes = series.episodes || [];
    const seasons = series.seasons || [];

    if (seasons.length) {
        const grouped = seasons.map((season,index) => ({
            number:season.number||season.season||index+1,
            episodes:season.episodes||[]
        }));

        area.innerHTML = `
            <div class="isa-vod-toolbar">
                <button class="isa-back" id="isa-series-back"><i class="fas fa-arrow-left"></i> Geri</button>
                <h2>${esc(series.name)}</h2>
            </div>
            ${series.poster ? `<img src="${esc(series.poster)}" style="width:130px;max-height:180px;object-fit:contain">` : ''}
            <div class="isa-provider-grid">
                ${grouped.map((season,index) => `
                    <button class="isa-provider-card" data-season="${index}">
                        <i class="fas fa-layer-group" style="font-size:32px;padding:20px"></i>
                        <strong>${esc('Sezon '+season.number)}</strong>
                        <small>${season.episodes.length} bölüm</small>
                    </button>
                `).join('')}
            </div>
        `;

        document.getElementById('isa-series-back').onclick = () => openVODProvider(provider);

        area.querySelectorAll('[data-season]').forEach(button => {
            button.onclick = () => showEpisodes(
                grouped[Number(button.dataset.season)].episodes,
                series,
                provider
            );
        });

        return;
    }

    if (!episodes.length) episodes = series.items || [];

    if (!episodes.length) {
        area.innerHTML = `
            <div class="isa-vod-toolbar">
                <button class="isa-back" id="isa-series-back">Geri</button>
                <h2>${esc(series.name)}</h2>
            </div>
            <p class="isa-vod-note">Bu dizinin JSON kaynağında bölüm listesi bulunmuyor.</p>
        `;
        document.getElementById('isa-series-back').onclick = () => openVODProvider(provider);
        return;
    }

    const grouped = new Map();

    episodes.forEach(episode => {
        const number = seasonNumber(episode);
        if (!grouped.has(number)) grouped.set(number,[]);
        grouped.get(number).push(episode);
    });

    if (grouped.size > 1) {
        area.innerHTML = `
            <div class="isa-vod-toolbar">
                <button class="isa-back" id="isa-series-back">Geri</button>
                <h2>${esc(series.name)}</h2>
            </div>
            <div class="isa-provider-grid">
                ${Array.from(grouped.entries()).map(([number,eps],index) => `
                    <button class="isa-provider-card" data-season="${index}">
                        <i class="fas fa-layer-group" style="font-size:32px;padding:20px"></i>
                        <strong>Sezon ${number}</strong>
                        <small>${eps.length} bölüm</small>
                    </button>
                `).join('')}
            </div>
        `;

        const values = Array.from(grouped.values());
        document.getElementById('isa-series-back').onclick = () => openVODProvider(provider);

        area.querySelectorAll('[data-season]').forEach(button => {
            button.onclick = () => showEpisodes(values[Number(button.dataset.season)],series,provider);
        });
    } else {
        showEpisodes(episodes,series,provider);
    }
}

function showEpisodes(episodes,series,provider) {
    const area = document.getElementById('isa-vod-items');

    area.innerHTML = `
        <div class="isa-vod-toolbar">
            <button class="isa-back" id="isa-episodes-back">
                <i class="fas fa-arrow-left"></i> Geri
            </button>
            <h2>${esc(series.name)}</h2>
        </div>
        <div class="isa-provider-grid">
            ${episodes.map((episode,index) => `
                <button class="isa-provider-card" data-episode="${index}">
                    <i class="fas fa-circle-play" style="font-size:35px;padding:20px"></i>
                    <strong>${esc(episode.title||episode.name||('Bölüm '+(index+1)))}</strong>
                    <small>${esc(episode.date||'Bölümü aç')}</small>
                </button>
            `).join('')}
        </div>
    `;

    document.getElementById('isa-episodes-back').onclick = () => showSeries(series,provider);

    area.querySelectorAll('[data-episode]').forEach(button => {
        button.onclick = () => openVODItem(episodes[Number(button.dataset.episode)]);
    });
}

function openVODItem(item) {
    const candidates = [
        item.videoUrl,
        item.playUrl,
        item.stream,
        item.file,
        item.url
    ].filter(Boolean);

    const media = candidates.find(isDirectMedia);

    if (media) {
        play({
            name:item.title||item.name||'İSA Flix',
            url:media,
            logo:item.poster||item.logo||'',
            group:'İSA Flix',
            headers:item.headers||{}
        },[],0);
        return;
    }

    const page = candidates.find(isHttp);

    if (page) {
        const area = document.getElementById('isa-vod-items');
        area.insertAdjacentHTML('afterbegin',`
            <div class="isa-vod-note">
                <strong>Bu içerik doğrudan video bağlantısı değil.</strong><br>
                Kaynak bir web sayfası adresi sağlıyor. Bu adres ExoPlayer'a gönderilmedi.
                <br><br>
                <button class="isa-action" id="isa-open-source-page">
                    Kaynak sayfasını aç
                </button>
            </div>
        `);
        document.getElementById('isa-open-source-page').onclick = () => openPage(page);
        return;
    }

    alert('Bu içerik için doğrudan medya bağlantısı bulunamadı.');
}

async function refreshAll(forceRefresh=false) {
    const status = document.getElementById('isa-live-status');
    status.textContent = forceRefresh
        ? 'Kaynaklar güncelleniyor...'
        : 'Önbellek ve kayıtlı listeler yükleniyor...';

    let live = [];
    let user = [];

    try {
        live = await loadLiveChannels(forceRefresh);
    } catch(error) {
        console.error('Güneş TV:',error);
    }

    try {
        user = await loadUserLists(forceRefresh);
    } catch(error) {
        console.error('Kullanıcı listeleri:',error);
    }

    channels = [...live,...user];
    renderChannels();
    renderSavedLists();

    status.textContent =
        live.length+' Güneş TV kanalı, '+
        user.length+' kişisel liste kanalı yüklendi.';

    try {
        await loadVOD(forceRefresh);
    } catch(error) {
        document.getElementById('isa-vod-status').textContent =
            'VOD kaynakları yüklenemedi: '+error.message;
    }
}

function bindControls() {
    document.getElementById('isa-add-url').onclick = async () => {
        const name = document.getElementById('isa-list-name').value.trim() || 'İnternet listesi';
        const url = document.getElementById('isa-list-url').value.trim();

        if (!isHttp(url)) {
            alert('Geçerli HTTP/HTTPS M3U adresi gir.');
            return;
        }

        if (playlists.some(item => item.type === 'url' && item.url === url)) {
            alert('Bu liste zaten eklenmiş.');
            return;
        }

        playlists.push({name,type:'url',url,text:''});
        saveLists();

        document.getElementById('isa-list-url').value = '';
        document.getElementById('isa-upload-status').textContent = 'Liste eklendi.';

        await refreshAll(false);
    };

    document.getElementById('isa-m3u-file').onchange = async event => {
        const file = event.target.files[0];
        if (!file) return;

        try {
            const text = await file.text();

            if (!text.includes('#EXTM3U') && !text.includes('#EXTINF:')) {
                throw new Error('Geçerli M3U dosyası değil.');
            }

            playlists.push({
                name:file.name,
                type:'file',
                text
            });

            saveLists();
            document.getElementById('isa-upload-status').textContent = file.name+' eklendi.';

            await refreshAll(false);
        } catch(error) {
            document.getElementById('isa-upload-status').textContent = error.message;
        }

        event.target.value = '';
    };

    document.getElementById('isa-refresh').onclick = () => refreshAll(true);

    document.querySelectorAll('[data-tab]').forEach(button => {
        button.onclick = () => {
            document.querySelectorAll('.isa-tab').forEach(tab => tab.classList.remove('active'));
            document.querySelectorAll('.isa-panel').forEach(panel => panel.classList.remove('active'));

            button.classList.add('active');
            document.getElementById(button.dataset.tab).classList.add('active');
            window.scrollTo({top:0,behavior:'smooth'});
        };
    });
}

function start() {
    loadSaved();
    bindControls();
    renderSavedLists();
    refreshAll(false);
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded',start);
} else {
    start();
}

})();
JS

echo "5/7 - Android köprü ve tam ekran oynatıcı düzeltiliyor..."

python3 - <<'PY'
from pathlib import Path
import re

main = Path("app/src/main/java/com/isatvhd/player/MainActivity.java")
s = main.read_text(encoding="utf-8")

if "public void openPage(String address)" not in s:
    marker = "    @JavascriptInterface\n    public void cachePut("
    method = r'''
    @JavascriptInterface
    public void openPage(String address) {
        try {
            if (address == null ||
                !(address.startsWith("https://") || address.startsWith("http://"))) {
                return;
            }
            runOnUiThread(() -> {
                try {
                    Intent browser = new Intent(Intent.ACTION_VIEW, Uri.parse(address));
                    startActivity(browser);
                } catch (Exception e) {
                    Log.e(TAG, "Kaynak sayfası açılamadı", e);
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "openPage hatası", e);
        }
    }

'''
    if marker not in s:
        raise SystemExit("MainActivity.java içinde cachePut konumu bulunamadı.")
    s = s.replace(marker,method+marker,1)

main.write_text(s,encoding="utf-8")

player = Path("app/src/main/java/com/isatvhd/player/PlayerActivity.java")
p = player.read_text(encoding="utf-8")

# Immersive tam ekran fonksiyonu
if "private void applyImmersiveMode()" not in p:
    marker = "    private void createInterface() {"
    method = r'''
    private void applyImmersiveMode() {
        final View decor = getWindow().getDecorView();
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

'''
    if marker not in p:
        raise SystemExit("PlayerActivity createInterface bulunamadı.")
    p = p.replace(marker,method+marker,1)

# onCreate başında immersive çağır
p = p.replace(
    "        super.onCreate(savedInstanceState);\n",
    "        super.onCreate(savedInstanceState);\n        applyImmersiveMode();\n",
    1
)

# Telefonlarda da native player logosu göster
p = re.sub(
    r'    private boolean shouldShowTvLogo\(\) \{.*?\n    \}',
    '    private boolean shouldShowTvLogo() { return true; }',
    p,
    count=1,
    flags=re.S
)

# Kanal listesi butonunu modernleştir
p = p.replace(
    '        channelButton.setAllCaps(false);\n',
    '''        channelButton.setAllCaps(false);
        channelButton.setTextColor(Color.WHITE);
        channelButton.setPadding(dp(18), dp(8), dp(18), dp(8));
        channelButton.setBackground(new android.graphics.drawable.GradientDrawable() {{
            setColor(0xCC18263A);
            setCornerRadius(dp(24));
            setStroke(dp(1), 0x66FFFFFF);
        }});
        channelButton.setElevation(dp(8));
'''
)

# Modern özel kanal listesi dialogu
start = p.find("    private void showChannelList() {")
end = p.find("    private boolean shouldShowTvLogo()",start)

if start < 0 or end < 0:
    raise SystemExit("PlayerActivity kanal listesi metodu bulunamadı.")

replacement = r'''
    private void showChannelList() {
        if (channels.isEmpty()) return;

        final android.app.Dialog dialog = new android.app.Dialog(this);
        android.widget.LinearLayout panel = new android.widget.LinearLayout(this);
        panel.setOrientation(android.widget.LinearLayout.VERTICAL);
        panel.setPadding(dp(18), dp(16), dp(18), dp(16));
        panel.setBackground(new android.graphics.drawable.GradientDrawable() {{
            setColor(0xF0141C29);
            setCornerRadius(dp(20));
            setStroke(dp(1), 0x33FFFFFF);
        }});

        TextView heading = new TextView(this);
        heading.setText("KANAL LİSTESİ");
        heading.setTextColor(Color.WHITE);
        heading.setTextSize(18);
        heading.setTypeface(null, android.graphics.Typeface.BOLD);
        heading.setPadding(dp(5), dp(5), dp(5), dp(14));
        panel.addView(heading);

        android.widget.ScrollView scroll = new android.widget.ScrollView(this);
        android.widget.LinearLayout list = new android.widget.LinearLayout(this);
        list.setOrientation(android.widget.LinearLayout.VERTICAL);

        for (int i = 0; i < channels.size(); i++) {
            final int position = i;
            Channel channel = channels.get(i);

            TextView row = new TextView(this);
            row.setText(
                (i == selectedIndex ? "▶  " : "   ")
                + channel.name
                + (channel.group == null ? "" : "\n      " + channel.group)
            );
            row.setTextColor(i == selectedIndex ? 0xFFFF6874 : Color.WHITE);
            row.setTextSize(14);
            row.setPadding(dp(14), dp(13), dp(14), dp(13));
            row.setBackground(new android.graphics.drawable.GradientDrawable() {{
                setColor(position == selectedIndex ? 0x553E536F : 0x221FFFFFF);
                setCornerRadius(dp(11));
            }});

            android.widget.LinearLayout.LayoutParams rowParams =
                new android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                );
            rowParams.setMargins(0, 0, 0, dp(7));
            list.addView(row, rowParams);

            row.setOnClickListener(v -> {
                selectedIndex = position;
                dialog.dismiss();
                playSelected();
            });
        }

        scroll.addView(list);
        panel.addView(scroll, new android.widget.LinearLayout.LayoutParams(
            android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
            dp(430)
        ));

        TextView close = new TextView(this);
        close.setText("KAPAT");
        close.setTextColor(Color.WHITE);
        close.setGravity(Gravity.CENTER);
        close.setPadding(dp(12), dp(14), dp(12), dp(8));
        close.setOnClickListener(v -> dialog.dismiss());
        panel.addView(close);

        dialog.setContentView(panel);
        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
            dialog.getWindow().setLayout(
                (int)(getResources().getDisplayMetrics().widthPixels * 0.88f),
                -2
            );
        }
        dialog.show();
        if (dialog.getWindow() != null) {
            dialog.getWindow().setBackgroundDrawableResource(android.R.color.transparent);
            dialog.getWindow().setLayout(
                (int)(getResources().getDisplayMetrics().widthPixels * 0.88f),
                -2
            );
        }
    }

'''
p = p[:start] + replacement + p[end:]

player.write_text(p,encoding="utf-8")
PY

echo "6/7 - Dosya kontrolleri..."

test -s "$JS"
test -s "$HTML"
test -s "$CSS"
test -s "$MAIN"
test -s "$PLAYER"

if command -v node >/dev/null 2>&1; then
    node --check "$JS"
else
    echo "Node.js bulunamadı; JavaScript sözdizimi kontrolü atlandı."
fi

echo "7/7 - APK oluşturuluyor..."

gradle --no-daemon clean assembleDebug

APK="app/build/outputs/apk/debug/app-debug.apk"

if [ ! -s "$APK" ]; then
    echo "HATA: APK oluşmadı."
    exit 1
fi

mkdir -p "$HOME/storage/downloads"
cp "$APK" "$HOME/storage/downloads/ISA-TV-HD.apk"

echo
echo "=========================================="
echo "İSA TV HD DÜZELTME İŞLEMİ TAMAMLANDI"
echo "=========================================="
echo "Yedek: $BACKUP"
echo "APK: $HOME/storage/downloads/ISA-TV-HD.apk"
echo
echo "APK dosyasını İndirilenler klasöründe bulabilirsin."
