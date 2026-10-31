(function () {
'use strict';

const LIVE_JSON = 'https://raw.githubusercontent.com/GeceHub/gunestv/main/live2.json';
const VOD_JSON = 'https://raw.githubusercontent.com/GeceHub/gunestv/main/vod2.json';
const STORAGE_KEY = 'isa-tv-playlists-v2';

let channels = [];
let playlists = [];
let bound = false;
let fetchCounter = 0;

window.__isaFetchCallbacks = {};

window.__isaFetchDone = function(id, result, error) {
    const callback = window.__isaFetchCallbacks[id];
    if (!callback) return;

    delete window.__isaFetchCallbacks[id];

    if (error) callback.reject(new Error(error));
    else callback.resolve(result);
};

function nativeFetch(url) {
    if (!window.ISATV || !window.ISATV.fetchText) {
        return fetch(url, {cache:'no-store'}).then(r => {
            if (!r.ok) throw new Error('HTTP ' + r.status);
            return r.text();
        });
    }

    return new Promise((resolve, reject) => {
        const id = ++fetchCounter;
        window.__isaFetchCallbacks[id] = {resolve, reject};
        window.ISATV.fetchText(url, String(id));
    });
}

async function getText(url) {
    return nativeFetch(url);
}

function escapeHtml(value) {
    return String(value || '').replace(/[&<>"']/g, c => ({
        '&':'&amp;', '<':'&lt;', '>':'&gt;',
        '"':'&quot;', "'":'&#39;'
    })[c]);
}

function loadSaved() {
    try {
        const value = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]');
        playlists = Array.isArray(value) ? value : [];
    } catch (_) {
        playlists = [];
    }
}

function saveLists() {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(playlists));
}

function parseM3U(text, prefix) {
    const lines = text.replace(/^\uFEFF/, '').split(/\r?\n/);
    const result = [];
    let current = null;
    let headers = {};

    for (const raw of lines) {
        const line = raw.trim();
        if (!line) continue;

        if (line.startsWith('#EXTINF:')) {
            const comma = line.lastIndexOf(',');
            const name = comma >= 0 ? line.slice(comma + 1).trim() : 'İsimsiz yayın';
            const group = (line.match(/group-title="([^"]*)"/i) || [])[1] || 'Genel';
            const logo = (line.match(/tvg-logo="([^"]*)"/i) || [])[1] || '';

            current = {
                name, group, logo, url:'',
                headers:{},
                id:prefix + '-' + result.length
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
        } else if (current && !line.startsWith('#') && /^https?:\/\//i.test(line)) {
            current.url = line;
            current.headers = {...headers};
            result.push(current);
            current = null;
            headers = {};
        }
    }

    return result;
}

function play(channel) {
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

function renderChannels() {
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

function ensureSections() {
    if (document.getElementById('isa-source-controls')) return;

    const style = document.createElement('style');
    style.textContent = `
    .isa-source-section,.isa-vod-section{padding:22px;margin:18px 0;background:#151515;border-radius:14px;color:white}
    .isa-source-heading{display:flex;align-items:center;justify-content:space-between;gap:12px}
    .isa-source-section input{width:100%;box-sizing:border-box;padding:13px;margin:8px 0;background:#222;color:white;border:1px solid #555;border-radius:8px}
    .isa-source-button,.isa-clear-button{padding:11px 15px;border:0;border-radius:8px;background:#e50914;color:white;margin:5px;cursor:pointer}
    .isa-list-row{display:flex;align-items:center;justify-content:space-between;gap:8px;padding:10px;background:#222;border-radius:8px;margin:8px 0}
    .isa-provider-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(145px,1fr));gap:12px}
    .isa-provider-card{background:#222;color:white;border:1px solid #444;border-radius:10px;padding:12px;cursor:pointer}
    .isa-provider-card img{width:100%;max-height:85px;object-fit:contain}
    `;
    document.head.appendChild(style);

    const area = document.createElement('section');
    area.id = 'isa-source-controls';
    area.className = 'isa-source-section';

    area.innerHTML = `
      <div class="isa-source-heading">
        <div><h2>İSA TV HD</h2><p>Yayın listelerim</p></div>
        <button id="isa-refresh" class="isa-source-button">Yenile</button>
      </div>

      <h3>M3U / M3U8 URL ekle</h3>
      <input id="isa-list-name" placeholder="Liste adı">
      <input id="isa-list-url" type="url" placeholder="https://site.com/liste.m3u">
      <button id="isa-add-url" class="isa-source-button">URL listesini ekle</button>

      <h3>Cihazdan liste ekle</h3>
      <input id="isa-m3u-file" type="file" accept=".m3u,.m3u8,.txt">
      <div id="isa-upload-status" aria-live="polite"></div>

      <h3>Kaydedilen listeler</h3>
      <div id="isa-saved-lists"></div>
      <div id="isa-live-status">Canlı yayınlar yükleniyor...</div>
    `;

    const hero = document.querySelector('.hero-showcase');
    if (hero) hero.insertAdjacentElement('afterend', area);
    else document.body.prepend(area);

    const live = document.createElement('section');
    live.id = 'isa-live-section';
    live.className = 'isa-vod-section';
    live.innerHTML = '<h2>Canlı TV</h2><div id="isa-live-grid" class="isa-provider-grid"></div>';

    const vod = document.createElement('section');
    vod.id = 'isa-vod-section';
    vod.className = 'isa-vod-section';
    vod.innerHTML = '<h2>Film ve Diziler</h2><div id="isa-vod-status"></div><div id="isa-vod-grid" class="isa-provider-grid"></div><div id="isa-vod-items"></div>';

    const content = document.querySelector('.content-rows');
    if (content) {
        content.insertAdjacentElement('beforebegin', live);
        live.insertAdjacentElement('afterend', vod);
    } else {
        area.insertAdjacentElement('afterend', live);
        live.insertAdjacentElement('afterend', vod);
    }

    document.querySelectorAll('.row-section,.categories-showcase')
        .forEach(e => e.style.display = 'none');
}

function renderSavedLists() {
    const box = document.getElementById('isa-saved-lists');
    if (!box) return;

    box.innerHTML = playlists.length ? playlists.map((p,i) => `
        <div class="isa-list-row">
            <span>${escapeHtml(p.name)} (${p.type === 'url' ? 'URL' : 'Dosya'})</span>
            <span>
              <button class="isa-source-button" data-refresh="${i}">Yenile</button>
              <button class="isa-clear-button" data-delete="${i}">Sil</button>
            </span>
        </div>
    `).join('') : '<p>Henüz liste eklenmedi.</p>';

    box.querySelectorAll('[data-refresh]').forEach(button => {
        button.onclick = async () => {
            await loadUserLists(Number(button.dataset.refresh));
        };
    });

    box.querySelectorAll('[data-delete]').forEach(button => {
        button.onclick = async () => {
            playlists.splice(Number(button.dataset.delete),1);
            saveLists();
            renderSavedLists();
            await refreshAll();
        };
    });
}

async function loadLiveChannels() {
    const data = JSON.parse(await getText(LIVE_JSON));
    if (!Array.isArray(data)) throw new Error('live2.json biçimi geçersiz');

    const results = await Promise.all(data.filter(p => p.url).map(async (p,i) => {
        try {
            const text = await getText(p.url);
            return parseM3U(text,'gunes-'+i).map(c => ({
                ...c,
                group:p.name + ' / ' + c.group,
                source:p.name
            }));
        } catch(e) {
            console.warn('Güneş TV paketi yüklenemedi:',p.name,e);
            return [];
        }
    }));

    return results.flat();
}

async function loadUserLists(selectedIndex) {
    const result = [];

    for (let i=0; i<playlists.length; i++) {
        if (selectedIndex !== undefined && i !== selectedIndex) continue;

        const item = playlists[i];

        try {
            if (item.type === 'url') {
                item.text = await getText(item.url);
                if (!item.text.includes('#EXTM3U') && !item.text.includes('#EXTINF:')) {
                    throw new Error('Geçerli M3U içeriği bulunamadı.');
                }
            }

            const parsed = parseM3U(item.text || '', 'user-'+i).map(c => ({
                ...c,
                group:item.name + ' / ' + c.group
            }));

            result.push(...parsed);
            item.lastCount = parsed.length;
            item.error = '';
        } catch(e) {
            item.error = e.message;
            console.warn(item.name,e);
        }
    }

    saveLists();
    return result;
}

async function loadVOD() {
    const providers = JSON.parse(await getText(VOD_JSON));
    if (!Array.isArray(providers)) throw new Error('vod2.json biçimi geçersiz');

    const grid = document.getElementById('isa-vod-grid');
    grid.innerHTML = providers.map((p,i) => `
        <button class="isa-provider-card" data-vod="${i}">
            <img src="${escapeHtml(p.poster || '')}" onerror="this.style.display='none'">
            <strong>${escapeHtml(p.name)}</strong>
            <small>${escapeHtml(p.description || '')}</small>
        </button>
    `).join('');

    grid.querySelectorAll('[data-vod]').forEach(button => {
        button.onclick = () => openVODProvider(providers[Number(button.dataset.vod)]);
    });

    document.getElementById('isa-vod-status').textContent =
        providers.length + ' VOD kaynağı hazır.';
}

function extractVODItems(data,result=[]) {
    if (Array.isArray(data)) {
        data.forEach(x => extractVODItems(x,result));
        return result;
    }

    if (!data || typeof data !== 'object') return result;

    const url = data.url || data.link || data.file || data.stream || data.playUrl || data.video;
    const name = data.name || data.title || data.baslik || data.titleName || data.filename;

    if (url && name && /^https?:\/\//i.test(url)) {
        result.push({
            name:String(name),url,
            logo:data.poster || data.image || data.cover || data.thumbnail || ''
        });
        return result;
    }

    Object.values(data).forEach(v => {
        if (v && typeof v === 'object') extractVODItems(v,result);
    });

    return result;
}

async function openVODProvider(provider) {
    const area = document.getElementById('isa-vod-items');
    area.textContent = 'İçerikler yükleniyor...';

    try {
        const text = await getText(provider.url);
        let items;

        if (text.trim().startsWith('#EXTM3U') || text.includes('#EXTINF:')) {
            items = parseM3U(text,'vod');
        } else {
            items = extractVODItems(JSON.parse(text));
        }

        area.innerHTML = '<h3>'+escapeHtml(provider.name)+'</h3><div class="isa-provider-grid">' +
            items.map((item,i) => `
                <button class="isa-provider-card" data-vod-item="${i}">
                    ${item.logo ? `<img src="${escapeHtml(item.logo)}">` : ''}
                    <strong>${escapeHtml(item.name)}</strong>
                </button>
            `).join('') + '</div>';

        area.querySelectorAll('[data-vod-item]').forEach(button => {
            button.onclick = () => play(items[Number(button.dataset.vodItem)]);
        });

        if (!items.length) area.textContent = 'Bu sağlayıcıdan otomatik içerik listesi alınamadı.';
    } catch(e) {
        area.textContent = 'VOD yüklenemedi: ' + e.message;
    }
}

async function refreshAll() {
    const status = document.getElementById('isa-live-status');
    status.textContent = 'Kaynaklar yenileniyor...';

    let live = [];
    try {
        live = await loadLiveChannels();
    } catch(e) {
        console.error(e);
    }

    const user = await loadUserLists();
    channels = [...live,...user];

    renderChannels();
    renderSavedLists();

    status.textContent = live.length + ' Güneş TV kanalı, ' +
        user.length + ' kişisel liste kanalı yüklendi.';

    try {
        await loadVOD();
    } catch(e) {
        document.getElementById('isa-vod-status').textContent =
            'VOD kaynakları yüklenemedi: ' + e.message;
    }
}

function bindUpload() {
    if (bound) return;
    bound = true;

    document.getElementById('isa-add-url').onclick = async () => {
        const name = document.getElementById('isa-list-name').value.trim() || 'İnternet listesi';
        const url = document.getElementById('isa-list-url').value.trim();

        if (!/^https?:\/\//i.test(url)) {
            alert('Geçerli bir HTTP/HTTPS liste adresi gir.');
            return;
        }

        if (playlists.some(p => p.type === 'url' && p.url === url)) {
            alert('Bu liste zaten eklenmiş.');
            return;
        }

        playlists.push({name,type:'url',url,text:''});
        saveLists();

        document.getElementById('isa-list-url').value = '';
        document.getElementById('isa-upload-status').textContent = 'Liste eklendi.';
        await refreshAll();
    };

    document.getElementById('isa-m3u-file').onchange = async event => {
        const file = event.target.files[0];
        if (!file) return;

        try {
            const text = await file.text();

            if (!text.includes('#EXTM3U') && !text.includes('#EXTINF:')) {
                throw new Error('Geçerli M3U listesi değil.');
            }

            playlists.push({
                name:file.name,
                type:'file',
                text
            });

            saveLists();
            document.getElementById('isa-upload-status').textContent =
                file.name + ' eklendi.';

            await refreshAll();
        } catch(e) {
            document.getElementById('isa-upload-status').textContent =
                'Hata: ' + e.message;
        }

        event.target.value = '';
    };

    document.getElementById('isa-refresh').onclick = refreshAll;
}

function patchHomepage() {
    if (typeof StreamFlixHomepage !== 'undefined') {
        StreamFlixHomepage.prototype.loadChannels = async function() {
            ensureSections();
            bindUpload();
            await refreshAll();
        };
    }
}

function start() {
    ensureSections();
    bindUpload();
    loadSaved();
    renderSavedLists();
    refreshAll();
}

patchHomepage();

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded',start);
} else {
    start();
}

})();
