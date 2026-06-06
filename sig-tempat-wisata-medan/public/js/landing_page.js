const LANDING_API_BASE = `${window.location.origin}/api`;

document.addEventListener('DOMContentLoaded', () => {
    initBerandaDarkMode();
    initScrollReveal();
    initLandingPage().catch((error) => {
        console.error('Error initializing landing page:', error);
        renderLandingFallback();
    });
});

/* Dark mode for beranda page */
function initBerandaDarkMode() {
    const saved = localStorage.getItem('terra-dark-mode');
    if (saved === 'true') {
        document.body.classList.add('dark');
    }
    updateBerandaDarkIcons();

    const btn = document.getElementById('btn-dark-mode-beranda');
    if (btn) {
        btn.addEventListener('click', () => {
            document.body.classList.toggle('dark');
            const isDark = document.body.classList.contains('dark');
            localStorage.setItem('terra-dark-mode', isDark);
            updateBerandaDarkIcons();
        });
    }
}

function updateBerandaDarkIcons() {
    const isDark = document.body.classList.contains('dark');
    const d = document.getElementById('beranda-icon-dark');
    const l = document.getElementById('beranda-icon-light');
    if (d) d.style.display = isDark ? 'none' : 'block';
    if (l) l.style.display = isDark ? 'block' : 'none';
}

/* Scroll Reveal via IntersectionObserver */
function initScrollReveal() {
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

async function initLandingPage() {
    const [wisataRes, kategoriRes] = await Promise.all([
        fetch(`${LANDING_API_BASE}/wisata`),
        fetch(`${LANDING_API_BASE}/kategori`),
    ]);

    const wisataJson = await wisataRes.json();
    const kategoriJson = await kategoriRes.json();

    const wisata = wisataJson?.data || [];
    const kategori = kategoriJson?.data || [];

    renderLandingStats(wisata, kategori);
    renderLandingCategories(kategori);
    renderLandingDestinations(wisata);
}

function renderLandingStats(wisata, kategori) {
    const total = wisata.length;
    const rated = wisata
        .map((item) => Number.parseFloat(item.rating) || 0)
        .filter((value) => value > 0);
    const averageRating = rated.length
        ? (rated.reduce((sum, value) => sum + value, 0) / rated.length).toFixed(1)
        : '0.0';
    const kecamatanCount = new Set(
        wisata
            .map((item) => String(item.kecamatan || '').trim())
            .filter(Boolean)
    ).size;
    const kategoriCount = kategori.length || new Set(
        wisata
            .map((item) => String(item.kategori || '').trim())
            .filter(Boolean)
    ).size;

    animateNumber('landing-stat-total', total);
    animateRating('landing-stat-rating', parseFloat(averageRating));
    animateNumber('landing-stat-kecamatan', kecamatanCount);
    animateNumber('landing-stat-kategori', kategoriCount);
    animateNumber('landing-hero-total', total);
    animateNumber('landing-hero-kecamatan', kecamatanCount);
}

function renderLandingCategories(kategori) {
    const container = document.getElementById('landing-category-pills');
    if (!container) return;

    const names = kategori
        .map((item) => item?.nama_kategori)
        .filter(Boolean)
        .slice(0, 10);

    if (names.length === 0) {
        container.innerHTML = '<span class="tm-chip">Belum ada kategori aktif</span>';
        return;
    }

    container.innerHTML = names.map((name) => `
        <a class="tm-chip" href="/peta?category=${encodeURIComponent(name)}">${escapeHtml(name)}</a>
    `).join('');
}

function renderLandingDestinations(wisata) {
    const container = document.getElementById('landing-destination-grid');
    if (!container) return;

    if (!wisata || wisata.length === 0) {
        container.innerHTML = '<div class="destination-card" style="padding:16px;"><div class="empty-panel">Belum ada destinasi aktif.</div></div>';
        return;
    }

    const sorted = [...wisata]
        .sort((a, b) => {
            const ratingDiff = Number(b.rating || 0) - Number(a.rating || 0);
            if (ratingDiff !== 0) return ratingDiff;
            const reviewDiff = Number(b.total_review || 0) - Number(a.total_review || 0);
            if (reviewDiff !== 0) return reviewDiff;
            return String(a.nama_tempat || '').localeCompare(String(b.nama_tempat || ''));
        })
        .slice(0, 8);

    container.innerHTML = sorted.map((item) => {
        const image = getPrimaryPhoto(item);
        const rating = Number.parseFloat(item.rating) || 0;
        const mapUrl = `/peta?focus=${item.id}&view=detail`;

        return `
            <article class="destination-card" onclick="window.location.href='${mapUrl}'">
                <div class="destination-media">
                    ${image ? `<img src="${escapeHtml(image)}" alt="${escapeHtml(item.nama_tempat || 'Wisata')}" loading="lazy">` : ''}
                    <div class="destination-rating">
                        <span>&#9733;</span>
                        <span>${rating > 0 ? rating.toFixed(1) : 'Belum ada'}</span>
                    </div>
                </div>
                <div class="destination-body">
                    <span class="tm-chip">${escapeHtml(item.kategori || 'Tanpa Kategori')}</span>
                    <h4>${escapeHtml(item.nama_tempat || 'Tanpa Nama')}</h4>
                    <p>${escapeHtml(item.deskripsi || 'Belum ada deskripsi untuk destinasi ini.')}</p>
                    <div class="destination-meta">
                        <span>${escapeHtml(item.kecamatan || '-')} &middot; ${escapeHtml(item.kelurahan || '-')}</span>
                        <a href="${mapUrl}" class="tm-btn tm-btn-ghost" style="min-height:34px; padding:0 12px;" onclick="event.stopPropagation();">Peta</a>
                    </div>
                </div>
            </article>
        `;
    }).join('');

    bindDestinationSliderControls();
}

function renderLandingFallback() {
    const categoryContainer = document.getElementById('landing-category-pills');
    const destinationContainer = document.getElementById('landing-destination-grid');

    if (categoryContainer) {
        categoryContainer.innerHTML = '<span class="tm-chip">Gagal memuat kategori</span>';
    }

    if (destinationContainer) {
        destinationContainer.innerHTML = '<div class="destination-card" style="padding:16px;"><div class="empty-panel">Gagal memuat daftar destinasi. Pastikan API berjalan.</div></div>';
    }
}

function getPrimaryPhoto(item) {
    if (Array.isArray(item?.foto) && item.foto.length > 0) {
        return item.foto[0];
    }

    if (typeof item?.foto === 'string' && item.foto.trim()) {
        return item.foto.trim();
    }

    return '';
}

function animateNumber(id, target) {
    const el = document.getElementById(id);
    if (!el) return;
    const duration = 1600;
    const start = performance.now();
    const step = (now) => {
        const progress = Math.min((now - start) / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 4);
        el.textContent = Math.round(eased * target).toLocaleString();
        if (progress < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
}

function animateRating(id, target) {
    const el = document.getElementById(id);
    if (!el) return;
    const duration = 1600;
    const start = performance.now();
    const step = (now) => {
        const progress = Math.min((now - start) / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 4);
        el.textContent = (eased * target).toFixed(1);
        if (progress < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
}

function setText(id, value) {
    const element = document.getElementById(id);
    if (element) {
        element.textContent = String(value);
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text ?? '';
    return div.innerHTML;
}

function bindDestinationSliderControls() {
    const container = document.getElementById('landing-destination-grid');
    const prevBtn = document.getElementById('landing-destination-prev');
    const nextBtn = document.getElementById('landing-destination-next');
    if (!container || !prevBtn || !nextBtn) return;

    const scrollByCard = (direction) => {
        const firstCard = container.querySelector('.destination-card');
        const cardWidth = firstCard ? firstCard.getBoundingClientRect().width + 18 : 320;
        container.scrollLeft += direction * cardWidth;
    };

    prevBtn.onclick = () => scrollByCard(-1);
    nextBtn.onclick = () => scrollByCard(1);
}
