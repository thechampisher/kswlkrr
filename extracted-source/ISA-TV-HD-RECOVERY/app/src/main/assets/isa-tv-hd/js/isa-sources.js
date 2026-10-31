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

    renderFavorites();

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


function renderFavorites() {
    const section = document.getElementById('isa-favorites-section');
    const grid = document.getElementById('isa-favorites-grid');
    if (!section || !grid) return;

    let favorites = [];

    try {
        if (window.ISATV && window.ISATV.getFavorites) {
            favorites = JSON.parse(window.ISATV.getFavorites() || '[]');
        }
    } catch(e) {
        console.warn('Favoriler okunamadı:', e);
    }

    if (!Array.isArray(favorites) || !favorites.length) {
        section.style.display = 'none';
        grid.innerHTML = '';
        return;
    }

    section.style.display = '';

    grid.innerHTML = favorites.map((item,index) => `
        <div class="channel-card isa-favorite-card" data-favorite-index="${index}">
            <div class="channel-thumbnail">
                ${item.logo
                    ? `<img src="${esc(item.logo)}" alt="" onerror="this.style.display='none'">`
                    : '<div class="channel-placeholder"><i class="fas fa-tv"></i></div>'}
            </div>
            <div class="channel-name">${esc(item.name || 'İsimsiz kanal')}</div>
            <small class="isa-favorite-label">♥ FAVORİ</small>
        </div>
    `).join('');

    grid.querySelectorAll('[data-favorite-index]').forEach(card => {
        card.addEventListener('click',() => {
            const item = favorites[Number(card.dataset.favoriteIndex)];
            if (!item || !item.url) return;
            const index = channels.findIndex(c => c.url === item.url);
            if (index >= 0) play(channels[index],channels,index);
            else play(item,favorites,Number(card.dataset.favoriteIndex));
        });
    });
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


function showVODProviders() {
    const grid = document.getElementById('isa-vod-grid');
    const area = document.getElementById('isa-vod-items');
    const heading = document.querySelector('#isa-vod-panel .isa-section-heading');

    grid.style.display = '';
    area.innerHTML = '';

    if (heading) heading.style.display = '';

    document.getElementById('isa-vod-status').textContent =
        vodProviders.length + ' VOD kaynağı hazır.';
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
            ${series.map(item => vodCard(item,'series',items.indexOf(item))).join('')}
        </div>

        ${films.length ? '<h3 style="margin-top:25px">Filmler ve diğer içerikler</h3>' : ''}
        <div class="isa-provider-grid">
            ${films.map(item => vodCard(item,'film',items.indexOf(item))).join('')}
        </div>

        ${!items.length ? '<p class="isa-vod-note">Bu kaynakta gösterilebilir içerik bulunamadı.</p>' : ''}
    `;

    document.getElementById('isa-vod-back').onclick = showVODProviders;

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
    const grid = document.getElementById('isa-vod-grid');
    const heading = document.querySelector('#isa-vod-panel .isa-section-heading');

    currentProvider = provider;
    grid.style.display = 'none';
    if (heading) heading.style.display = 'none';

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
                <button class="isa-back" onclick="showVODProviders()">
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

    // Önce "2.Sezon 1.Bölüm" biçimini kontrol et.
    let match = title.match(/(?:^|\b)(\d+)\s*\.?\s*(?:sezon|season)\b/i);

    // Ardından "Season 2" biçimini kontrol et.
    if (!match) {
        match = title.match(/(?:season|sezon|s)\s*0*(\d+)/i);
    }

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

    if (grouped.size >= 1) {
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
