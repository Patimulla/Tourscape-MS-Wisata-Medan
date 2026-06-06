const DETAIL_API_BASE = `${window.location.origin}/api`;
let detailInlineMap = null;

document.addEventListener('DOMContentLoaded', () => {
    initDetailDarkMode();
    initDetailScrollReveal();
    initWisataDetailPage().catch((error) => {
        console.error('Error initializing detail page:', error);
        showDetailError();
    });
});

/* Dark mode for detail page */
function initDetailDarkMode() {
    const saved = localStorage.getItem('terra-dark-mode');
    if (saved === 'true') {
        document.body.classList.add('dark');
    }
    updateDetailDarkIcons();

    const btn = document.getElementById('btn-dark-mode-detail');
    if (btn) {
        btn.addEventListener('click', () => {
            document.body.classList.toggle('dark');
            const isDark = document.body.classList.contains('dark');
            localStorage.setItem('terra-dark-mode', isDark);
            updateDetailDarkIcons();
        });
    }
}

function updateDetailDarkIcons() {
    const isDark = document.body.classList.contains('dark');
    const d = document.getElementById('detail-icon-dark');
    const l = document.getElementById('detail-icon-light');
    if (d) d.style.display = isDark ? 'none' : 'block';
    if (l) l.style.display = isDark ? 'block' : 'none';
}

/* Scroll Reveal */
function initDetailScrollReveal() {
    const animElements = document.querySelectorAll('[data-anim]');
    if (animElements.length === 0) return;

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const delay = parseInt(entry.target.dataset.delay || '0', 10);
                setTimeout(() => {
                    entry.target.classList.add('visible');
                }, delay);
                observer.unobserve(entry.target);
            }
        });
    }, { threshold: 0.1, rootMargin: '0px 0px -40px 0px' });

    animElements.forEach(el => observer.observe(el));
}

async function initWisataDetailPage() {
    const wisataId = Number(window.WISATA_DETAIL_ID);
    if (!wisataId) {
        showDetailError();
        return;
    }

    const response = await fetch(`${DETAIL_API_BASE}/wisata/${wisataId}`);
    const json = await response.json();

    if (!json?.status || !json?.data) {
        showDetailError();
        return;
    }

    renderWisataDetail(json.data);
}

function renderWisataDetail(wisata) {
    const photos = normalizePhotos(wisata.foto);
    const heroImage = photos[0] || createFallbackImage(wisata.nama_tempat || 'GeoWisata');
    const rating = Number.parseFloat(wisata.rating_avg ?? wisata.rating) || 0;

    setSource('detail-hero-image', heroImage, wisata.nama_tempat || 'Wisata');
    setText('detail-title', wisata.nama_tempat || 'Tanpa Nama');
    setText('detail-address', wisata.alamat || `${wisata.kecamatan || '-'}, ${wisata.kelurahan || '-'}`);
    setText('detail-side-title', wisata.nama_tempat || 'Tanpa Nama');
    setText(
        'detail-side-subtitle',
        wisata.target_pengunjung
            ? `Target pengunjung: ${capitalizeWords(wisata.target_pengunjung)}`
            : 'Destinasi wisata yang terhubung langsung dengan peta publik dan detail operasionalnya.'
    );
    setText('detail-description', wisata.deskripsi || 'Belum ada deskripsi untuk destinasi ini.');

    setChipText('detail-category-chip', wisata.kategori || 'Tanpa Kategori');
    setChipText('detail-rating-chip', rating > 0 ? `★ ${rating.toFixed(1)}` : 'Belum ada rating');

    const mapLink = `/peta?focus=${wisata.id}&view=detail`;
    const mapButton = document.getElementById('detail-open-map');
    if (mapButton) {
        mapButton.href = mapLink;
    }

    const copyButton = document.getElementById('detail-copy-address');
    if (copyButton) {
        copyButton.addEventListener('click', async () => {
            const address = wisata.alamat || `${wisata.kecamatan || '-'}, ${wisata.kelurahan || '-'}`;
            try {
                await navigator.clipboard.writeText(address);
                copyButton.textContent = 'Alamat Tersalin';
                setTimeout(() => {
                    copyButton.textContent = 'Salin Alamat';
                }, 1800);
            } catch (error) {
                console.error('Clipboard write failed:', error);
            }
        });
    }

    renderInfoGrid(wisata, rating);
    renderFacilities(wisata);
    renderGallery(photos);
    renderReviews(wisata.reviews || []);
    initInlineMap(wisata);

    toggleHidden('detail-loading', true);
    toggleHidden('detail-error', true);
    toggleHidden('detail-shell', false);
    toggleHidden('detail-sections', false);
}

function renderInfoGrid(wisata, rating) {
    const grid = document.getElementById('detail-info-grid');
    if (!grid) return;

    const items = [
        ['Alamat', wisata.alamat || '-'],
        ['Kecamatan', wisata.kecamatan || '-'],
        ['Kelurahan / Desa', wisata.kelurahan || '-'],
        ['Jam Operasional', `${wisata.jam_buka || '-'} - ${wisata.jam_tutup || '-'}`],
        ['Hari Operasional', wisata.hari_operasional || '-'],
        ['Harga Tiket', Number(wisata.harga_tiket) > 0 ? formatRupiah(wisata.harga_tiket) : 'Gratis'],
        ['No. Telepon', wisata.no_telepon || '-'],
        ['Rating', rating > 0 ? rating.toFixed(1) : 'Belum ada'],
        ['Target Pengunjung', wisata.target_pengunjung ? capitalizeWords(wisata.target_pengunjung) : '-'],
        ['Keterangan Harga', wisata.keterangan_harga || '-'],
    ];

    grid.innerHTML = items.map(([label, value]) => `
        <div class="detail-info-card">
            <strong>${escapeHtml(label)}</strong>
            <span>${escapeHtml(value)}</span>
        </div>
    `).join('');
}

function renderFacilities(wisata) {
    const container = document.getElementById('detail-facilities');
    if (!container) return;

    const facilities = [
        ['Toilet', Boolean(wisata.toilet)],
        ['Parkir', Boolean(wisata.parkir)],
        ['Area Bermain', Boolean(wisata.area_bermain)],
        ['Tempat Makan', Boolean(wisata.tempat_makan)],
        ['Mushola', Boolean(wisata.mushola)],
        ['WiFi', Boolean(wisata.wifi)],
    ];

    container.innerHTML = facilities.map(([label, active]) => `
        <div class="facility-item">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                ${active
                    ? '<path d="M20 6L9 17l-5-5"></path>'
                    : '<line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line>'}
            </svg>
            <strong>${escapeHtml(label)}</strong>
            <span>${active ? 'Tersedia' : 'Belum tersedia'}</span>
        </div>
    `).join('');
}

function renderGallery(photos) {
    const container = document.getElementById('detail-gallery');
    if (!container) return;

    if (!photos.length) {
        container.innerHTML = '<div class="empty-panel">Belum ada foto tambahan untuk destinasi ini.</div>';
        return;
    }

    container.innerHTML = photos.map((photo, index) => `
        <div class="gallery-card">
            <img src="${escapeHtml(photo)}" alt="Foto ${index + 1}">
        </div>
    `).join('');
}

function renderReviews(reviews) {
    const container = document.getElementById('detail-reviews');
    if (!container) return;

    if (!reviews.length) {
        container.innerHTML = '<div class="empty-panel">Belum ada ulasan pengunjung.</div>';
        return;
    }

    container.innerHTML = reviews.map((review) => `
        <div class="review-panel">
            <div class="review-panel-header">
                <strong>${escapeHtml(review.nama_reviewer || 'Pengunjung')}</strong>
                <span>${'★'.repeat(Math.min(5, Math.max(0, Math.round(Number(review.rating) || 0))))}</span>
            </div>
            <p>${escapeHtml(review.ulasan || 'Tidak ada komentar tambahan.')}</p>
        </div>
    `).join('');
}

function initInlineMap(wisata) {
    const lat = Number.parseFloat(wisata.latitude);
    const lng = Number.parseFloat(wisata.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
        const mapContainer = document.getElementById('detail-inline-map');
        if (mapContainer) {
            mapContainer.innerHTML = '<div class="empty-panel" style="height:100%; display:flex; align-items:center; justify-content:center;">Koordinat belum tersedia.</div>';
        }
        return;
    }

    if (detailInlineMap) {
        detailInlineMap.remove();
        detailInlineMap = null;
    }

    detailInlineMap = L.map('detail-inline-map', {
        center: [lat, lng],
        zoom: 15,
        zoomControl: true,
        attributionControl: false,
        dragging: true,
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors',
    }).addTo(detailInlineMap);

    L.marker([lat, lng]).addTo(detailInlineMap).bindPopup(escapeHtml(wisata.nama_tempat || 'Lokasi')).openPopup();
}

function showDetailError() {
    toggleHidden('detail-loading', true);
    toggleHidden('detail-shell', true);
    toggleHidden('detail-sections', true);
    toggleHidden('detail-error', false);
}

function toggleHidden(id, hidden) {
    const element = document.getElementById(id);
    if (!element) return;
    element.classList.toggle('hidden', hidden);
}

function setText(id, value) {
    const element = document.getElementById(id);
    if (element) {
        element.textContent = String(value ?? '');
    }
}

function setChipText(id, value) {
    const element = document.getElementById(id);
    if (element) {
        element.textContent = String(value ?? '');
    }
}

function setSource(id, src, alt) {
    const element = document.getElementById(id);
    if (element) {
        element.src = src;
        element.alt = alt || '';
    }
}

function normalizePhotos(raw) {
    if (Array.isArray(raw)) {
        return raw.filter(Boolean);
    }

    if (typeof raw === 'string' && raw.trim()) {
        return [raw.trim()];
    }

    return [];
}

function createFallbackImage(label) {
    const svg = `
        <svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800" viewBox="0 0 1200 800">
            <defs>
                <linearGradient id="g" x1="0" x2="1" y1="0" y2="1">
                    <stop offset="0%" stop-color="#362115"/>
                    <stop offset="100%" stop-color="#7d562d"/>
                </linearGradient>
            </defs>
            <rect width="1200" height="800" fill="url(#g)"/>
            <circle cx="920" cy="140" r="180" fill="rgba(255,219,202,0.18)"/>
            <text x="80" y="420" fill="#ffffff" font-size="54" font-family="Montserrat, sans-serif" font-weight="700">${escapeSvg(label)}</text>
            <text x="80" y="480" fill="rgba(255,255,255,0.78)" font-size="24" font-family="Inter, sans-serif">GeoWisata Medan &amp; Deli Serdang</text>
        </svg>
    `;
    return `data:image/svg+xml;charset=UTF-8,${encodeURIComponent(svg)}`;
}

function formatRupiah(value) {
    return `Rp ${Number(value).toLocaleString('id-ID')}`;
}

function capitalizeWords(value) {
    return String(value || '')
        .split(/\s+/)
        .filter(Boolean)
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
        .join(' ');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text ?? '';
    return div.innerHTML;
}

function escapeSvg(text) {
    return String(text || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}
