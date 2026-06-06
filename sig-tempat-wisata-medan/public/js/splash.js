/* ============================================================
   SPLASH PAGE — JavaScript
   Dark mode + scroll animations + stats loading + parallax
   ============================================================ */

const SPLASH_API = `${window.location.origin}/api`;

document.addEventListener('DOMContentLoaded', () => {
    initDarkMode();
    initScrollEffects();
    initMobileNav();
    initParallax();
    loadSplashStats();
});

/* ---------- DARK MODE (Global, saved in localStorage) ---------- */
function initDarkMode() {
    const saved = localStorage.getItem('terra-dark-mode');
    if (saved === 'true') {
        document.body.classList.add('dark');
    }
    updateDarkModeIcons();

    const btn = document.getElementById('btn-dark-mode');
    if (btn) {
        btn.addEventListener('click', () => {
            document.body.classList.toggle('dark');
            const isDark = document.body.classList.contains('dark');
            localStorage.setItem('terra-dark-mode', isDark);
            updateDarkModeIcons();
        });
    }
}

function updateDarkModeIcons() {
    const isDark = document.body.classList.contains('dark');
    const iconDark = document.getElementById('icon-dark');
    const iconLight = document.getElementById('icon-light');
    if (iconDark) iconDark.style.display = isDark ? 'none' : 'block';
    if (iconLight) iconLight.style.display = isDark ? 'block' : 'none';
}

/* ---------- SCROLL EFFECTS ---------- */
function initScrollEffects() {
    const topbar = document.getElementById('splash-topbar');

    // Topbar scroll class
    const onScroll = () => {
        if (topbar) {
            topbar.classList.toggle('scrolled', window.scrollY > 60);
        }
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    // Intersection Observer for [data-anim]
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
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

    animElements.forEach(el => observer.observe(el));
}

/* ---------- PARALLAX ---------- */
function initParallax() {
    const heroImg = document.querySelector('.splash-hero-bg img');
    if (!heroImg) return;

    let ticking = false;
    window.addEventListener('scroll', () => {
        if (!ticking) {
            requestAnimationFrame(() => {
                const scrollY = window.scrollY;
                const heroHeight = window.innerHeight;
                if (scrollY < heroHeight) {
                    const translate = scrollY * 0.3;
                    const scale = 1 + scrollY * 0.0003;
                    heroImg.style.transform = `translateY(${translate}px) scale(${scale})`;
                }
                ticking = false;
            });
            ticking = true;
        }
    }, { passive: true });
}

/* ---------- MOBILE NAV ---------- */
function initMobileNav() {
    const btn = document.getElementById('btn-mobile-nav');
    const nav = document.getElementById('splash-nav');
    if (!btn || !nav) return;

    btn.addEventListener('click', () => {
        nav.classList.toggle('mobile-open');
    });

    document.addEventListener('click', (e) => {
        if (!nav.contains(e.target) && !btn.contains(e.target)) {
            nav.classList.remove('mobile-open');
        }
    });
}

/* ---------- STATS LOADING ---------- */
async function loadSplashStats() {
    try {
        const [wisataRes, kategoriRes] = await Promise.all([
            fetch(`${SPLASH_API}/wisata`),
            fetch(`${SPLASH_API}/kategori`),
        ]);

        const wisataJson = await wisataRes.json();
        const wisata = wisataJson?.data || [];

        const total = wisata.length;
        const rated = wisata.map(w => parseFloat(w.rating) || 0).filter(v => v > 0);
        const avgRating = rated.length
            ? (rated.reduce((s, v) => s + v, 0) / rated.length).toFixed(1)
            : '0.0';
        const kecamatan = new Set(
            wisata.map(w => (w.kecamatan || '').trim()).filter(Boolean)
        ).size;

        animateNumber('splash-stat-destinasi', total);
        animateNumber('splash-stat-kecamatan', kecamatan);
        animateRating('splash-stat-rating', parseFloat(avgRating));
    } catch (err) {
        console.error('Error loading splash stats:', err);
    }
}

function animateNumber(id, target) {
    const el = document.getElementById(id);
    if (!el) return;
    const duration = 1600;
    const start = performance.now();
    const step = (now) => {
        const progress = Math.min((now - start) / duration, 1);
        // Cubic ease-out for smooth deceleration
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
    const el = document.getElementById(id);
    if (el) el.textContent = String(value);
}
