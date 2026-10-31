/* ISA TV HD - Türkçe Arayüz */
(function () {
'use strict';
document.documentElement.lang = 'tr';

const dictionary = {
  "Home": "Ana Sayfa",
  "TV Shows": "TV Programları",
  "Live": "Canlı Yayın",
  "Downloads": "İndirmeler",
  "Download": "İndir",
  "About": "Hakkında",
  "Playlist": "Yayın Listesi",
  "Global": "Dünya",
  "India (Optional)": "Hindistan (İsteğe Bağlı)",
  "Recommended": "Önerilen",
  "Browse": "Göz At",
  "Browse Channels": "Kanallara Göz At",
  "All Channels": "Tüm Kanallar",
  "Popular Channels": "Popüler Kanallar",
  "Continue Watching": "İzlemeye Devam Et",
  "Browse by Category": "Kategoriye Göre Göz At",
  "News & Sports": "Haberler ve Spor",
  "Entertainment": "Eğlence",
  "Music": "Müzik",
  "Kids & Family": "Çocuk ve Aile",
  "Search channels...": "Kanal ara...",
  "Search Channels": "Kanal Ara",
  "Load More Channels": "Daha Fazla Kanal Yükle",
  "Start Watching": "İzlemeye Başla",
  "Premium Live Streaming": "Kesintisiz Canlı Yayın Deneyimi",
  "Experience thousands of live channels with crystal clear quality": "Binlerce canlı kanalı yüksek görüntü kalitesiyle izleyin.",
  "Play URL": "Bağlantı Oynat",
  "Back to Home": "Ana Sayfaya Dön",
  "Back Home": "Ana Sayfaya Dön",
  "Select a channel to begin streaming": "Yayına başlamak için bir kanal seçin",
  "Loading premium content...": "İçerik yükleniyor...",
  "Loading channels...": "Kanallar yükleniyor...",
  "Loading...": "Yükleniyor...",
  "Loading": "Yükleniyor",
  "No channels found": "Kanal bulunamadı",
  "No channels available": "Kullanılabilir kanal yok",
  "Previous": "Önceki",
  "Next": "Sonraki",
  "Play": "Oynat",
  "Pause": "Duraklat",
  "Mute": "Sesi Kapat",
  "Unmute": "Sesi Aç",
  "Volume": "Ses Seviyesi",
  "Settings": "Ayarlar",
  "Fullscreen": "Tam Ekran",
  "Exit Fullscreen": "Tam Ekrandan Çık",
  "Theater Mode": "Sinema Modu",
  "Picture in Picture": "Resim İçinde Resim",
  "Now Playing": "Şimdi Oynatılıyor",
  "Channel List": "Kanal Listesi",
  "Search": "Ara",
  "Category": "Kategori",
  "All": "Tümü",
  "Favorites": "Favorilerim",
  "Recently Watched": "Son İzlenenler",
  "Watch History": "İzleme Geçmişi",
  "Refresh": "Yenile",
  "Retry": "Tekrar Dene",
  "Cancel": "İptal",
  "Close": "Kapat",
  "Save": "Kaydet",
  "Submit": "Gönder",
  "OK": "Tamam",
  "Error": "Hata",
  "Success": "Başarılı",
  "Warning": "Uyarı",
  "Information": "Bilgi",
  "Connection Error": "Bağlantı Hatası",
  "Check your internet connection": "İnternet bağlantınızı kontrol edin",
  "Stream unavailable": "Yayın kullanılamıyor",
  "Playback Error": "Oynatma Hatası",
  "Select Playlist": "Yayın Listesi Seç",
  "Choose a channel": "Bir kanal seçin",
  "Channel": "Kanal",
  "Channels": "Kanallar",
  "Live TV": "Canlı TV",
  "Video Player": "Video Oynatıcı",
  "Downloads Center": "İndirme Merkezi",
  "Download StreamFlix Apps": "İSA TV HD İndirme Sayfası",
  "Windows": "Windows",
  "Linux": "Linux",
  "Android": "Android",
  "Coming Soon": "Yakında",
  "File:": "Dosya:",
  "Version": "Sürüm",
  "Description": "Açıklama",
  "Contact": "İletişim",
  "Disclaimer": "Yasal Uyarı",
  "Educational project": "Eğitim amaçlı proje",
  "Premium": "Premium",
  "HD": "HD",
  "Back": "Geri",
  "Open menu": "Menüyü aç",
  "Close menu": "Menüyü kapat",
  "Show More": "Daha Fazla Göster",
  "Show Less": "Daha Az Göster",
  "Load More": "Daha Fazla Yükle",
  "Play Channel": "Kanalı Oynat",
  "Enter URL": "Bağlantı adresini girin",
  "Enter stream URL": "Yayın bağlantısını girin",
  "Play Custom URL": "Özel Bağlantı Oynat",
  "Paste URL here": "Bağlantıyı buraya yapıştırın",
  "Network Error": "Ağ Hatası",
  "Something went wrong": "Bir sorun oluştu",
  "Try again": "Tekrar deneyin",
  "About Us": "Hakkımızda",
  "Privacy Policy": "Gizlilik Politikası",
  "Terms of Service": "Kullanım Koşulları",
  "Select a category": "Bir kategori seçin",
  "All Categories": "Tüm Kategoriler",
  "Recently Added": "Son Eklenenler",
  "Live Channels": "Canlı Kanallar",
  "VOD": "Film ve Diziler",
  "Movies": "Filmler",
  "Series": "Diziler",
  "Continue": "Devam Et",
  "Exit": "Çıkış",
  "Yes": "Evet",
  "No": "Hayır"
};

function translateText(value) {
    const trimmed = value.trim();
    if (!trimmed) return value;
    if (dictionary[trimmed]) {
        return value.replace(trimmed, dictionary[trimmed]);
    }
    return value;
}

function translateElement(root) {
    if (!root) return;

    const walker = document.createTreeWalker(
        root,
        NodeFilter.SHOW_TEXT
    );

    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);

    nodes.forEach(node => {
        const translated = translateText(node.nodeValue);
        if (translated !== node.nodeValue) {
            node.nodeValue = translated;
        }
    });

    if (root.nodeType === 1) {
        ['placeholder', 'aria-label', 'title'].forEach(attr => {
            if (root.hasAttribute(attr)) {
                const oldValue = root.getAttribute(attr);
                if (dictionary[oldValue]) {
                    root.setAttribute(attr, dictionary[oldValue]);
                }
            }
        });
    }

    if (root.querySelectorAll) {
        root.querySelectorAll('[placeholder], [aria-label], [title]').forEach(el => {
            ['placeholder', 'aria-label', 'title'].forEach(attr => {
                const oldValue = el.getAttribute(attr);
                if (oldValue && dictionary[oldValue]) {
                    el.setAttribute(attr, dictionary[oldValue]);
                }
            });
        });
    }
}

function run() {
    translateElement(document.body);

    const observer = new MutationObserver(records => {
        records.forEach(record => {
            if (record.type === 'characterData') {
                const translated = translateText(record.target.nodeValue);
                if (translated !== record.target.nodeValue) {
                    record.target.nodeValue = translated;
                }
            }

            record.addedNodes.forEach(node => {
                if (node.nodeType === 1 || node.nodeType === 3) {
                    translateElement(node);
                }
            });
        });
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true,
        characterData: true
    });
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
} else {
    run();
}
})();