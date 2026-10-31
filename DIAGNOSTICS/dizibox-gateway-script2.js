
(function() {
    var TARGET_URL = "https://www.dizibox.live/100-days-of-deception-1-sezon-1-bolum-izle/";
    var gwLog = window.__gwLog || function() {};
    var origFetch = window.__origFetch || window.fetch.bind(window);

    var AD_KEYWORDS = [
        "googlesyndication", "doubleclick", "google-analytics", "googletagmanager",
        "facebook.com", "twitter.com", "instagram.com", "yandex", "mc.yandex",
        "adskeeper", "exoclick", "popads", "popcash", "propellerads", "adsterra",
        "hilltopads", "monetag", "trafficjunky", "juicyads", "tsyndicate",
        "chatango", "disqus", "recaptcha", "hcaptcha", "challenges.cloudflare",
        "turnstile", "/cdn-cgi/", "histats", "waust.at", "gemius", "clarity.ms",
        "statbest", "perfectadd", "kralbet", "marsbet", "malker", "xpartner", "t2m.co"
    ];

    function isAdOrTracker(url) {
        if (!url || typeof url !== "string") return true;
        var lower = url.toLowerCase();
        if (lower.indexOf("javascript:") === 0 || lower.indexOf("about:") === 0 || lower.indexOf("data:") === 0 || lower.indexOf("mailto:") === 0) {
            return true;
        }
        for (var i = 0; i < AD_KEYWORDS.length; i++) {
            if (lower.indexOf(AD_KEYWORDS[i]) !== -1) return true;
        }
        return false;
    }

    function resolveUrl(raw, base) {
        if (!raw || typeof raw !== "string") return "";
        var cleaned = raw.replace(/\\\//g, "/").replace(/&amp;/g, "&").replace(/\\u0026/g, "&").trim();
        if (!cleaned) return "";
        if (cleaned.indexOf("//") === 0) {
            var proto = "https:";
            try {
                if (base && base.indexOf("http:") === 0) proto = "http:";
            } catch (e) {}
            return proto + cleaned;
        }
        try {
            return new URL(cleaned, base || window.location.href).href;
        } catch (e) {
            return cleaned;
        }
    }

    function guessLang(url, label, lang) {
        var combined = ((url || "") + " " + (label || "") + " " + (lang || "")).toLowerCase();
        if (combined.indexOf("turk") !== -1 || combined.indexOf("türk") !== -1 || /(?:^|[^a-z])(tr|tur)(?:[^a-z]|$)/.test(combined)) {
            return { code: "tr", label: "Türkçe" };
        }
        if (combined.indexOf("ingiliz") !== -1 || combined.indexOf("english") !== -1 || /(?:^|[^a-z])(en|eng)(?:[^a-z]|$)/.test(combined)) {
            return { code: "en", label: "İngilizce" };
        }
        return { code: lang || "tr", label: label || "Türkçe" };
    }

    // Fetch a page through Android WebView's interceptBootstrapJsonRequest using the user's residential IP
    function gatewayFetch(url, timeoutMs) {
        return new Promise(function(resolve, reject) {
            var timer = setTimeout(function() {
                reject(new Error("timeout"));
            }, timeoutMs || 14000);

            origFetch(url, {
                method: "GET",
                credentials: "include",
                referrerPolicy: "no-referrer",
                headers: {
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                }
            }).then(function(resp) {
                clearTimeout(timer);
                if (!resp.ok && resp.status >= 400) {
                    reject(new Error("HTTP " + resp.status));
                    return;
                }
                return resp.text();
            }).then(function(text) {
                if (typeof text === "string") {
                    resolve(text);
                } else {
                    reject(new Error("Empty body"));
                }
            }).catch(function(err) {
                clearTimeout(timer);
                reject(err);
            });
        });
    }

    // Universal Dean Edwards Packer (p,a,c,k,e,d) unpacker
    function unpackDeanEdwards(p, a, c, k) {
        try {
            var encodeBase = function(val, radix) {
                var chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
                if (val < radix) {
                    return val < 36 ? val.toString(36) : chars.charAt(val);
                }
                return encodeBase(Math.floor(val / radix), radix) + (val % radix < 36 ? (val % radix).toString(36) : chars.charAt(val % radix));
            };
            while (c--) {
                if (k[c]) {
                    var token = encodeBase(c, a);
                    p = p.replace(new RegExp("\\b" + token + "\\b", "g"), k[c]);
                }
            }
            return p;
        } catch (e) {
            return "";
        }
    }

    function extractAndUnpackPacker(text) {
        var unpackedChunks = [];
        try {
            var regex = /eval\s*\(\s*function\s*\(\s*p\s*,\s*a\s*,\s*c\s*,\s*k\s*,\s*e\s*,\s*[dr]\s*\)\s*\{[\s\S]*?\}\s*\(\s*(['"])([\s\S]*?)\1\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(['"])([\s\S]*?)\5\.split\s*\(\s*['"]\|['"]\s*\)/gi;
            var m;
            while ((m = regex.exec(text)) !== null) {
                var payload = m[2].replace(/\\'/g, "'").replace(/\\"/g, '"');
                var radix = parseInt(m[3], 10);
                var count = parseInt(m[4], 10);
                var symtab = m[6].split("|");
                var res = unpackDeanEdwards(payload, radix, count, symtab);
                if (res && res.length > 10) {
                    unpackedChunks.push(res);
                }
            }
        } catch (e) {}
        return unpackedChunks;
    }

    function decryptCryptoJsBlocks(text) {
        var decryptedChunks = [];
        if (typeof CryptoJS === "undefined" || !CryptoJS.AES) return decryptedChunks;

        var JsonFormatter = {
            stringify: function(cipherParams) {
                var j = { ct: cipherParams.ciphertext.toString(CryptoJS.enc.Base64) };
                if (cipherParams.iv) j.iv = cipherParams.iv.toString();
                if (cipherParams.salt) j.s = cipherParams.salt.toString();
                return JSON.stringify(j);
            },
            parse: function(jsonStr) {
                var j = JSON.parse(jsonStr);
                var cipherParams = CryptoJS.lib.CipherParams.create({ ciphertext: CryptoJS.enc.Base64.parse(j.ct) });
                if (j.iv) cipherParams.iv = CryptoJS.enc.Hex.parse(j.iv);
                if (j.s) cipherParams.salt = CryptoJS.enc.Hex.parse(j.s);
                return cipherParams;
            }
        };

        try {
            var regex = /CryptoJS\.AES\.decrypt\s*\(\s*(['"`])([\s\S]*?)\1\s*,\s*(['"`])([\s\S]*?)\3/gi;
            var m;
            while ((m = regex.exec(text)) !== null) {
                var rawCipher = m[2];
                var pass = m[4];
                if (!rawCipher || !pass) continue;

                // 1. Standard OpenSSL format ("U2FsdGVkX1...")
                try {
                    var dec1 = CryptoJS.AES.decrypt(rawCipher, pass).toString(CryptoJS.enc.Utf8);
                    if (dec1 && dec1.length > 5) {
                        if ((dec1.charAt(0) === '"' && dec1.charAt(dec1.length - 1) === '"') ||
                            (dec1.charAt(0) === "'" && dec1.charAt(dec1.length - 1) === "'")) {
                            try { dec1 = JSON.parse(dec1); } catch (e) {}
                        }
                        decryptedChunks.push(dec1);
                        continue;
                    }
                } catch (e) {}

                // 2. CryptoJS JSON format ('{"ct":"...","iv":"...","s":"..."}')
                try {
                    var unescapedCipher = rawCipher.replace(/\\"/g, '"').replace(/\\\//g, "/");
                    if (unescapedCipher.indexOf('"ct"') !== -1) {
                        var dec2 = CryptoJS.AES.decrypt(unescapedCipher, pass, { format: JsonFormatter }).toString(CryptoJS.enc.Utf8);
                        if (dec2 && dec2.length > 5) {
                            try {
                                if (dec2.charAt(0) === '"') dec2 = JSON.parse(dec2);
                            } catch (e) {}
                            decryptedChunks.push(dec2);
                        }
                    }
                } catch (e) {}
            }
        } catch (e) {}
        return decryptedChunks;
    }

    function decodeBase64AndEconfigBlocks(text) {
        var chunks = [];
        // 1. atob("...")
        try {
            var atobRegex = /atob\s*\(\s*(['"])([A-Za-z0-9+\/=]{20,})\1\s*\)/gi;
            var m;
            while ((m = atobRegex.exec(text)) !== null) {
                try {
                    var dec = atob(m[2]);
                    if (dec && dec.length > 10) chunks.push(dec);
                } catch (e) {}
            }
        } catch (e) {}

        // 2. unescape("...")
        try {
            var unescRegex = /unescape\s*\(\s*(['"])(%[0-9A-Fa-f]{2}[\s\S]{15,}?)\1\s*\)/gi;
            var um;
            while ((um = unescRegex.exec(text)) !== null) {
                try {
                    var udec = unescape(um[2]);
                    if (udec && udec.length > 10) chunks.push(udec);
                } catch (e) {}
            }
        } catch (e) {}

        // 3. _p8 char-shift obfuscation
        try {
            var p8Regex = /_p8\s*=\s*(['"])([A-Za-z0-9+\/=]{20,})\1/i;
            var p8m = p8Regex.exec(text);
            if (p8m) {
                var rev = atob(p8m[2].split("").reverse().join(""));
                var key = "K9L";
                var n = "";
                for (var i = 0; i < rev.length; i++) {
                    var diff = (key.charCodeAt(i % 3) % 5) + 1;
                    n += String.fromCharCode(rev.charCodeAt(i) - diff);
                }
                var p8Json = atob(n);
                if (p8Json) chunks.push(p8Json);
            }
        } catch (e) {}

        // 4. _econfig 4-part permutation obfuscation
        try {
            var ecRegex = /_econfig\s*=\s*(['"`])([A-Za-z0-9+\/=]{24,})\1/i;
            var ecm = ecRegex.exec(text);
            if (ecm) {
                var order = [2, 0, 3, 1];
                var raw = atob(ecm[2].trim());
                var chunkSize = Math.floor(raw.length / 4);
                if (chunkSize > 3) {
                    var decodedParts = ["", "", "", ""];
                    for (var idx = 0; idx < 4; idx++) {
                        var part = raw.substring(idx * chunkSize, (idx + 1) * chunkSize);
                        var stripped = part.substring(0, 3) + part.substring(4);
                        decodedParts[order[idx]] = atob(stripped);
                    }
                    var ecJson = atob(decodedParts.join(""));
                    if (ecJson) chunks.push(ecJson);
                }
            }
        } catch (e) {}

        return chunks;
    }

    function decodeAllObfuscations(initialHtml) {
        var combined = initialHtml || "";
        var frontier = initialHtml || "";
        for (var pass = 0; pass < 4; pass++) {
            var newBlocks = [];
            var aesBlocks = decryptCryptoJsBlocks(frontier);
            for (var i = 0; i < aesBlocks.length; i++) newBlocks.push(aesBlocks[i]);

            var packedBlocks = extractAndUnpackPacker(frontier);
            for (var j = 0; j < packedBlocks.length; j++) newBlocks.push(packedBlocks[j]);

            var b64Blocks = decodeBase64AndEconfigBlocks(frontier);
            for (var k = 0; k < b64Blocks.length; k++) newBlocks.push(b64Blocks[k]);

            if (newBlocks.length === 0) break;
            frontier = newBlocks.join("\n");
            combined += "\n/* DECODED_PASS_" + pass + " */\n" + frontier;
        }
        return combined;
    }

    function extractSubtitles(text, baseUrl, outSubsMap) {
        if (!text) return;
        var unescaped = text.replace(/\\\//g, "/");

        function addSub(rawUrl, rawLabel, rawLang) {
            var full = resolveUrl(rawUrl, baseUrl);
            if (!full || full.indexOf("http") !== 0 || isAdOrTracker(full)) return;
            var key = full.split("#")[0].trim().toLowerCase();
            if (outSubsMap[key]) return;
            var info = guessLang(full, rawLabel, rawLang);
            outSubsMap[key] = {
                url: full,
                lang: info.code,
                label: info.label
            };
        }

        // 1. JSON track objects: {"file":"...vtt","label":"Türkçe",...}
        var objRegex = /\{[^{}]{0,250}?(?:["']?(?:file|src|url)["']?\s*:\s*["']([^"']+\.(?:vtt|srt)(?:\?[^"']*)?)["'])[^{}]{0,250}?\}/gi;
        var m;
        while ((m = objRegex.exec(unescaped)) !== null) {
            var chunk = m[0];
            var sUrl = m[1];
            var lblM = /["']?(?:label|name|title|display)["']?\s*:\s*["']([^"']+)["']/i.exec(chunk);
            var lngM = /["']?(?:lang|language|srclang)["']?\s*:\s*["']([^"']+)["']/i.exec(chunk);
            addSub(sUrl, lblM ? lblM[1] : "", lngM ? lngM[1] : "");
        }

        // 2. HTML <track> elements
        var trackRegex = /<track[^>]+src=["']([^"']+)["'][^>]*>/gi;
        var tm;
        while ((tm = trackRegex.exec(unescaped)) !== null) {
            var tag = tm[0];
            var tUrl = tm[1];
            var tLbl = /label=["']([^"']+)["']/i.exec(tag);
            var tLng = /srclang=["']([^"']+)["']/i.exec(tag);
            addSub(tUrl, tLbl ? tLbl[1] : "", tLng ? tLng[1] : "");
        }

        // 3. Direct .vtt / .srt URLs
        var rawSubRegex = /(?:https?:)?\/\/[^\s"'<>\\]+\.(?:vtt|srt)(?:\?[^\s"'<>\\]*)?/gi;
        var rm;
        while ((rm = rawSubRegex.exec(unescaped)) !== null) {
            addSub(rm[0], "", "");
        }
    }

    function isStaticNonVideoAsset(lowerUrl) {
        var clean = lowerUrl.split("?")[0].split("#")[0];
        var badExts = [
            ".vtt", ".srt", ".js", ".css", ".png", ".jpg", ".jpeg", ".gif",
            ".svg", ".webp", ".ico", ".woff", ".woff2", ".ttf", ".eot", ".xml", ".html", ".htm"
        ];
        for (var i = 0; i < badExts.length; i++) {
            if (clean.slice(-badExts[i].length) === badExts[i]) return true;
        }
        return false;
    }

    // Site-agnostic stream extractor: works on any player setup or media URL regardless of domain or path names
    function extractStreams(text, currentUrl) {
        var candidates = [];
        var seen = {};
        if (!text) return candidates;
        var unescaped = text.replace(/\\\//g, "/").replace(/\\u0026/g, "&");

        function addCandidate(rawUrl, kind, priority) {
            var full = resolveUrl(rawUrl, currentUrl);
            if (!full || full.indexOf("http") !== 0 || isAdOrTracker(full)) return;
            var lower = full.toLowerCase();
            if (isStaticNonVideoAsset(lower)) return;
            if (seen[full]) return;
            seen[full] = true;
            candidates.push({ url: full, kind: kind, priority: priority });
        }

        // 1. Direct .m3u8 / .mpd URLs anywhere in the document/scripts
        var hlsRegex = /(?:https?:)?\/\/[^\s"'<>\\]+\.(?:m3u8|mpd)(?:\?[^\s"'<>\\]*)?/gi;
        var hm;
        while ((hm = hlsRegex.exec(unescaped)) !== null) {
            addCandidate(hm[0], "hls_or_dash", 1);
        }

        // 2. Universal Player Setup / Config Media Properties (file, source, stream, videoUrl, playbackUrl, hls, stream_url, tm, cm)
        // Accepts BOTH standard .m3u8/.mpd/.mp4 URLs AND extensionless HLS/DASH endpoints (whenever assigned to a player media property)
        var propRegex = /["']?(?:file|source|stream|videoUrl|playbackUrl|hls|stream_url|tm|cm)["']?\s*:\s*["']((?:https?:)?\/\/[^"'\s<>]+|\/[A-Za-z0-9_.\-\/]{4,})["']/gi;
        var pm;
        while ((pm = propRegex.exec(unescaped)) !== null) {
            var val = pm[1].trim();
            var fullVal = resolveUrl(val, currentUrl);
            if (!fullVal || fullVal.indexOf("http") !== 0) continue;
            var lval = fullVal.toLowerCase();
            if (isStaticNonVideoAsset(lval)) continue;
            // Ignore intermediate PHP wrapper pages unless they are stream/m.php endpoints
            if (lval.indexOf(".php") !== -1 && lval.indexOf("stream.php") === -1 && lval.indexOf("m.php") === -1) continue;

            if (lval.indexOf(".m3u8") !== -1 || lval.indexOf(".mpd") !== -1 ||
                lval.indexOf("master.txt") !== -1 || lval.indexOf("playlist.txt") !== -1 ||
                lval.indexOf("stream.php") !== -1 || lval.indexOf("m.php") !== -1) {
                addCandidate(fullVal, "hls_or_dash", 1);
            } else if (lval.indexOf(".mp4") !== -1 || lval.indexOf(".webm") !== -1 || lval.indexOf(".mkv") !== -1) {
                addCandidate(fullVal, "mp4", 2);
            } else {
                // Extensionless stream URL inside player config (e.g. JWPlayer/PlayerJS/DPlayer setup)
                addCandidate(fullVal, "extensionless_hls", 1);
            }
        }

        // 3. Direct .mp4 URLs (non-preview/non-ad)
        var mp4Regex = /(?:https?:)?\/\/[^\s"'<>\\]+\.mp4(?:\?[^\s"'<>\\]*)?/gi;
        var mm;
        while ((mm = mp4Regex.exec(unescaped)) !== null) {
            var mp4Url = mm[0];
            if (!/preview|trailer|thumb|poster/i.test(mp4Url)) {
                addCandidate(mp4Url, "mp4", 3);
            }
        }

        candidates.sort(function(a, b) { return a.priority - b.priority; });
        return candidates;
    }

    // Stage 2 Fallback: Universal Sandboxed Player-API Emulation for unknown/custom JS obfuscators
    function runInPlayerSandbox(html, currentUrl, subsMap) {
        var captured = [];
        try {
            var scriptRe = /<script(?:\s+[^>]*)?>([\s\S]*?)<\/script>/gi;
            var inlineScripts = [];
            var m;
            while ((m = scriptRe.exec(html)) !== null) {
                var code = m[1] || "";
                if (code.trim().length > 20) {
                    inlineScripts.push(code);
                }
            }
            if (inlineScripts.length === 0) return captured;

            function inspectConfigObj(cfg) {
                if (!cfg || typeof cfg !== "object") return;
                var rawMedia = cfg.file || cfg.source || cfg.stream || cfg.videoUrl || cfg.playbackUrl || cfg.url || "";
                if (typeof rawMedia === "string" && rawMedia.length > 4) {
                    var full = resolveUrl(rawMedia, currentUrl);
                    if (full && full.indexOf("http") === 0 && !isStaticNonVideoAsset(full.toLowerCase())) {
                        var isExtless = full.toLowerCase().indexOf(".m3u8") === -1 && full.toLowerCase().indexOf(".mpd") === -1 && full.toLowerCase().indexOf(".mp4") === -1;
                        captured.push({ url: full, kind: isExtless ? "extensionless_hls" : "hls_or_dash", priority: 1 });
                    }
                }
                if (Array.isArray(cfg.sources)) {
                    for (var i = 0; i < cfg.sources.length; i++) inspectConfigObj(cfg.sources[i]);
                }
                if (Array.isArray(cfg.playlist)) {
                    for (var j = 0; j < cfg.playlist.length; j++) inspectConfigObj(cfg.playlist[j]);
                }
                if (Array.isArray(cfg.tracks || cfg.subtitles || cfg.subs)) {
                    extractSubtitles(JSON.stringify(cfg.tracks || cfg.subtitles || cfg.subs), currentUrl, subsMap);
                }
            }

            var noop = function() { return mockPlayer; };
            var mockPlayer = {
                setup: function(cfg) { inspectConfigObj(cfg); return mockPlayer; },
                load: function(cfg) { inspectConfigObj(cfg); return mockPlayer; },
                on: noop, once: noop, off: noop, play: noop, pause: noop,
                getState: function() { return "playing"; },
                getQualityLevels: function() { return [{ label: "1080p" }]; },
                getCurrentQuality: function() { return 0; },
                setCurrentQuality: noop
            };

            // Temporarily install universal player spies on window
            var prevJw = window.jwplayer;
            var prevPjs = window.Playerjs;
            var prevDp = window.DPlayer;
            var prevDev = window.devtoolsDetector;

            window.jwplayer = function() { return mockPlayer; };
            window.jwplayer.key = "";
            window.Playerjs = function(cfg) { inspectConfigObj(cfg); return mockPlayer; };
            window.DPlayer = function(cfg) { if (cfg && cfg.video) inspectConfigObj(cfg.video); inspectConfigObj(cfg); return mockPlayer; };
            window.devtoolsDetector = {
                addListener: function(fn) {
                    try { if (typeof fn === "function") fn(false, {}); } catch (e) {}
                },
                launch: noop, lanuch: noop, stop: noop
            };

            for (var s = 0; s < inlineScripts.length; s++) {
                var sanitized = inlineScripts[s]
                    .replace(/\bdebugger\b/g, "/*nop*/")
                    .replace(/window\.stop\s*\(\s*\)/g, "/*nop*/")
                    .replace(/location\.reload\s*\(\s*\)/g, "/*nop*/")
                    .replace(/console\.clear\s*\(\s*\)/g, "/*nop*/");
                try {
                    var fn = new Function(sanitized);
                    fn();
                    if (typeof window.load === "function") {
                        try { window.load(); } catch (e) {}
                    }
                    if (typeof window.loadi === "function") {
                        try { window.loadi(1); } catch (e) {}
                    }
                } catch (e) {}
                if (captured.length > 0) break;
            }

            window.jwplayer = prevJw;
            window.Playerjs = prevPjs;
            window.DPlayer = prevDp;
            window.devtoolsDetector = prevDev;
        } catch (e) {}
        return captured;
    }

    // Site-agnostic alternative player page detector: finds any <option> or <a> pointing to a sub-page (/2/, /3/) or query variant (?part=2) of the current page
    function extractAlternativePlayerPages(html, pageUrl) {
        var alts = [];
        var seen = {};
        if (!html || !pageUrl) return alts;
        var baseClean = pageUrl.split("?")[0].replace(/\/$/, "");
        seen[baseClean] = true;

        try {
            var parser = new DOMParser();
            var doc = parser.parseFromString(html, "text/html");
            var candidates = doc.querySelectorAll("option[value], a[href]");
            for (var i = 0; i < candidates.length; i++) {
                var el = candidates[i];
                var raw = el.getAttribute("value") || el.getAttribute("href") || "";
                var full = resolveUrl(raw, pageUrl);
                if (!full || full.indexOf("http") !== 0 || isAdOrTracker(full)) continue;
                var fullNoHash = full.split("#")[0];
                var clean = fullNoHash.replace(/\/$/, "");
                if (seen[clean]) continue;

                // Match either a numeric sub-path of the current episode URL (e.g. /episode-slug/2) or query variant (?p=2, ?part=2, ?player=2)
                var rest = clean.indexOf(baseClean) === 0 ? clean.slice(baseClean.length) : "";
                if (/^\/\d+$/.test(rest) || /^\?(?:part|player|source|p|alter|vid)=\w+/i.test(rest)) {
                    seen[clean] = true;
                    alts.push(fullNoHash);
                }
            }
        } catch (e) {}
        return alts;
    }

    // Site-agnostic iframe discovery and scoring (no hardcoded CSS classes or filenames)
    function extractNextIframes(text, currentUrl) {
        var iframes = [];
        var seen = {};
        if (!text) return iframes;

        function addIframe(rawUrl, priority) {
            if (!rawUrl) return;
            var full = resolveUrl(rawUrl, currentUrl);
            if (!full || full.indexOf("http") !== 0 || isAdOrTracker(full)) return;
            if (full === currentUrl) return;

            // Universal Base64 query parameter unwrapper: if any query parameter is Base64 for an http(s) URL, also queue the decoded embed URL
            try {
                var uObj = new URL(full);
                uObj.searchParams.forEach(function(val) {
                    if (val && val.length >= 16 && /^[A-Za-z0-9+\/=]+$/.test(val)) {
                        try {
                            var decV = atob(val).trim();
                            if (decV.indexOf("http://") === 0 || decV.indexOf("https://") === 0) {
                                decV = decV.replace(/^http:\/\//i, "https://").replace("ok.ru/video/", "ok.ru/videoembed/");
                                if (!seen[decV]) {
                                    seen[decV] = true;
                                    iframes.push({ url: decV, priority: priority });
                                }
                            }
                        } catch (e) {}
                    }
                });
            } catch (e) {}

            if (seen[full]) return;
            seen[full] = true;
            iframes.push({ url: full, priority: priority });
        }

        // 1. Universal DOM parsing: score each <iframe> by standard HTML5 video attributes (allowfullscreen, allow, dimensions)
        try {
            var parser = new DOMParser();
            var doc = parser.parseFromString(text, "text/html");
            var allFrames = doc.querySelectorAll("iframe");
            for (var fi = 0; fi < allFrames.length; fi++) {
                var f = allFrames[fi];
                var fSrc = f.getAttribute("src") || f.getAttribute("data-src") || f.getAttribute("data-litespeed-src") || f.getAttribute("data-lazy-src") || "";
                if (!fSrc) continue;

                var score = 5;
                var hasFs = f.hasAttribute("allowfullscreen") || f.hasAttribute("webkitallowfullscreen") || f.hasAttribute("mozallowfullscreen");
                var allowAttr = (f.getAttribute("allow") || "").toLowerCase();
                if (hasFs || allowAttr.indexOf("fullscreen") !== -1 || allowAttr.indexOf("autoplay") !== -1) {
                    score -= 3;
                }
                var w = (f.getAttribute("width") || "").toLowerCase();
                var h = (f.getAttribute("height") || "").toLowerCase();
                if (w === "0" || h === "0" || w === "1" || h === "1") {
                    score += 10;
                } else if (w === "100%" || parseInt(w, 10) >= 400 || parseInt(h, 10) >= 240) {
                    score -= 1;
                }
                addIframe(fSrc, score);
            }
        } catch (e) {}

        // 2. Regex fallback for iframes inside decoded JS strings or raw HTML
        var unescaped = text.replace(/\\\//g, "/");
        var iframeRegex = /<iframe[^>]+(?:src|data-src|data-lazy-src)=["']([^"']+)["'][^>]*>/gi;
        var im;
        while ((im = iframeRegex.exec(unescaped)) !== null) {
            var tag = im[0].toLowerCase();
            var prio = tag.indexOf("allowfullscreen") !== -1 ? 2 : 4;
            addIframe(im[1], prio);
        }

        iframes.sort(function(a, b) { return a.priority - b.priority; });
        return iframes;
    }

    function reportSubtitlesToApp(subsMap) {
        var keys = Object.keys(subsMap || {});
        if (keys.length === 0) return;
        var payload = [];
        for (var i = 0; i < keys.length; i++) {
            var s = subsMap[keys[i]];
            payload.push("browser_track_sub:" + s.lang + "|" + s.label + "|" + s.url);
            payload.push("sub_jw:" + s.url + "|" + s.label);
            window.console.log("browser_track_sub:" + s.lang + "|" + s.label + "|" + s.url);
        }
        try {
            if (window.VideoExtractor && typeof window.VideoExtractor.onVideoUrlsFound === "function") {
                window.VideoExtractor.onVideoUrlsFound(JSON.stringify(payload));
            }
        } catch (e) {}
    }

    function deliverStreamToApp(candidate, embedRefererUrl, subsMap) {
        gwLog("Stream extracted (" + candidate.kind + "): " + candidate.url + " | referer=" + embedRefererUrl);

        // 1. Report all discovered subtitles first so capturedSubtitles is populated before stream validation finishes
        reportSubtitlesToApp(subsMap);

        var streamUrl = candidate.url;
        var b64Stream = btoa(unescape(encodeURIComponent(streamUrl)));
        var sourcePhpBridge = window.location.origin + "/player/source.php?b64=" + encodeURIComponent(b64Stream);

        if (candidate.kind === "extensionless_hls") {
            origFetch(streamUrl, {
                method: "GET",
                mode: "no-cors",
                referrerPolicy: "no-referrer",
                headers: {
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                }
            }).catch(function() {});

            setTimeout(function() {
                try {
                    if (window.VideoExtractor && typeof window.VideoExtractor.onVideoUrlsFound === "function") {
                        window.VideoExtractor.onVideoUrlsFound(JSON.stringify(["dplayer_json:" + streamUrl]));
                    }
                } catch (e) {}
            }, 120);
        } else {
            try {
                if (window.VideoExtractor && typeof window.VideoExtractor.onVideoUrlsFound === "function") {
                    window.VideoExtractor.onVideoUrlsFound(JSON.stringify(["dplayer_json:" + sourcePhpBridge]));
                }
            } catch (e) {}
        }
    }

    // Recursive depth-first iframe chain resolver: tries all candidate iframes at each depth (up to depth 5)
    async function resolveNode(currentUrl, depth, visitedUrls, subsMap, collectAltsOut) {
        if (depth >= 5 || !currentUrl || visitedUrls[currentUrl]) {
            return { success: false, deepestUrl: currentUrl };
        }
        visitedUrls[currentUrl] = true;

        gwLog("Hop " + (depth + 1) + " fetching: " + currentUrl);
        var rawHtml = "";
        try {
            rawHtml = await gatewayFetch(currentUrl, 14000);
        } catch (err) {
            gwLog("Hop " + (depth + 1) + " fetch error: " + (err && err.message ? err.message : err));
            return { success: false, deepestUrl: currentUrl };
        }

        if (!rawHtml || rawHtml.length < 20) {
            return { success: false, deepestUrl: currentUrl };
        }

        if (depth === 0 && Array.isArray(collectAltsOut)) {
            var alts = extractAlternativePlayerPages(rawHtml, currentUrl);
            for (var a = 0; a < alts.length; a++) {
                collectAltsOut.push(alts[a]);
            }
        }

        // Stage 1: Static multi-pass deobfuscation & universal stream property extraction
        var decodedText = decodeAllObfuscations(rawHtml);
        extractSubtitles(decodedText, currentUrl, subsMap);

        var streams = extractStreams(decodedText, currentUrl);
        if (streams.length === 0) {
            // Stage 2: Sandboxed Player-API emulation for custom/unknown JS obfuscators
            streams = runInPlayerSandbox(decodedText, currentUrl, subsMap);
        }

        if (streams.length > 0) {
            deliverStreamToApp(streams[0], currentUrl, subsMap);
            return { success: true, deepestUrl: currentUrl };
        }

        // Follow all candidate iframes in priority order (if iframe #1 is dead/non-video, automatically tries iframe #2, etc.)
        var nextIframes = extractNextIframes(decodedText, currentUrl);
        var deepest = depth > 0 ? currentUrl : "";
        for (var i = 0; i < nextIframes.length && i < 4; i++) {
            var childUrl = nextIframes[i].url;
            if (!deepest) deepest = childUrl;
            var res = await resolveNode(childUrl, depth + 1, visitedUrls, subsMap, null);
            if (res.success) return res;
            if (res.deepestUrl) deepest = res.deepestUrl;
        }

        return { success: false, deepestUrl: deepest };
    }

    async function startGateway() {
        if (!TARGET_URL || TARGET_URL.indexOf("http") !== 0) {
            gwLog("Invalid target URL");
            return;
        }

        var subsMap = {};
        var visitedUrls = {};
        var altPlayerPages = [];
        var primaryResult = await resolveNode(TARGET_URL, 0, visitedUrls, subsMap, altPlayerPages);
        if (primaryResult.success) return;

        // If primary player failed and episode page has alternative players (/2/, /3/), try them automatically
        for (var i = 0; i < altPlayerPages.length && i < 3; i++) {
            gwLog("Trying alternative player page #" + (i + 2) + ": " + altPlayerPages[i]);
            var altResult = await resolveNode(altPlayerPages[i], 0, visitedUrls, subsMap, null);
            if (altResult.success) return;
            if (!primaryResult.deepestUrl && altResult.deepestUrl) {
                primaryResult.deepestUrl = altResult.deepestUrl;
            }
        }

        // Last-resort fallback: mount the deepest discovered embed URL in a live iframe and re-enable WebView sniffers
        var fallbackUrl = primaryResult.deepestUrl || TARGET_URL;
        gwLog("Falling back to live iframe: " + fallbackUrl);
        window.__gatewayShieldActive = false;
        var container = document.getElementById("fallback-container");
        if (container) {
            container.style.display = "block";
            var ifr = document.createElement("iframe");
            ifr.src = fallbackUrl;
            ifr.setAttribute("allowfullscreen", "true");
            ifr.setAttribute("allow", "autoplay; fullscreen; encrypted-media");
            container.appendChild(ifr);
        }
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", startGateway, { once: true });
    } else {
        startGateway();
    }
})();
