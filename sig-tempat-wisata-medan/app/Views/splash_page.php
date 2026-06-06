<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Tourscape MS — Sistem Informasi Geografis pemetaan destinasi wisata Kota Medan dan Kabupaten Deli Serdang berbasis Leaflet & OpenStreetMap.">
    <title>Tourscape MS — Pemetaan Wisata Interaktif</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800;900&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="/css/terra-medan.css?v=3.0">
    <link rel="stylesheet" href="/css/splash.css?v=3.0">
</head>
<body class="splash-page">
    <script>
        (function() {
            const saved = localStorage.getItem('terra-dark-mode');
            if (saved === 'true') {
                document.body.classList.add('dark');
            }
        })();
    </script>

    <!-- ========== NAVBAR ========== -->
    <header class="splash-topbar" id="splash-topbar">
        <div class="tm-shell splash-topbar-inner">
            <a href="/" class="splash-brand">
                <div class="splash-brand-mark">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                        <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 1 1 18 0z"></path>
                        <circle cx="12" cy="10" r="3"></circle>
                    </svg>
                </div>
                <span class="splash-brand-text">Tourscape MS</span>
            </a>

            <nav class="splash-nav" id="splash-nav">
                <a class="splash-nav-link active" href="/">Home</a>
                <a class="splash-nav-link" href="/explore">Explore</a>
                <a class="splash-nav-link" href="/peta">Peta Interaktif</a>
                <a class="splash-nav-link" href="/about">About</a>
                
            </nav>

            <div class="splash-header-actions">
                <button id="btn-dark-mode" class="splash-btn-icon" title="Toggle Dark Mode" aria-label="Toggle Dark Mode">
                    <svg id="icon-dark" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
                    </svg>
                    <svg id="icon-light" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="display:none">
                        <circle cx="12" cy="12" r="5"></circle>
                        <line x1="12" y1="1" x2="12" y2="3"></line>
                        <line x1="12" y1="21" x2="12" y2="23"></line>
                        <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
                        <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
                        <line x1="1" y1="12" x2="3" y2="12"></line>
                        <line x1="21" y1="12" x2="23" y2="12"></line>
                        <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
                        <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
                    </svg>
                </button>
                <button id="btn-mobile-nav" class="splash-btn-icon splash-mobile-only" title="Menu" aria-label="Menu">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="3" y1="12" x2="21" y2="12"></line>
                        <line x1="3" y1="6" x2="21" y2="6"></line>
                        <line x1="3" y1="18" x2="21" y2="18"></line>
                    </svg>
                </button>
            </div>
        </div>
    </header>

    <!-- ========== HERO ========== -->
    <section class="splash-hero">
        <div class="splash-hero-bg">
            <img src="/images/hero-medan.png" alt="Panorama Kota Medan" loading="eager">
            <div class="splash-hero-overlay"></div>
            <div class="splash-hero-orb splash-hero-orb-1"></div>
            <div class="splash-hero-orb splash-hero-orb-2"></div>
            <div class="splash-hero-orb splash-hero-orb-3"></div>
        </div>
        <div class="tm-shell splash-hero-inner">
            <div class="splash-hero-content" data-anim="fadeUp">
                <div class="splash-hero-badge">
                    <span class="pulse-dot"></span>
                    Sistem Informasi Geografis
                </div>
                <h1>Peta Wisata<br><span class="gradient-text">Kota Medan &amp; Deli Serdang</span></h1>
                <p>Jelajahi destinasi wisata terbaik di Sumatera Utara melalui peta interaktif berbasis GIS. Data tervalidasi, navigasi real-time, dan informasi lengkap dalam satu platform.</p>
                <div class="splash-hero-actions">
                    <a href="/peta" class="splash-cta-primary">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <polygon points="1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6"></polygon>
                            <line x1="8" y1="2" x2="8" y2="18"></line>
                            <line x1="16" y1="6" x2="16" y2="22"></line>
                        </svg>
                        Buka Peta Interaktif
                    </a>
                    <a href="/explore" class="splash-cta-secondary">
                        Explore
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <line x1="5" y1="12" x2="19" y2="12"></line>
                            <polyline points="12 5 19 12 12 19"></polyline>
                        </svg>
                    </a>
                </div>
            </div>
            <div class="splash-hero-stats" data-anim="fadeUp" data-delay="200">
                <div class="splash-stat-card glass-card">
                    <div class="splash-stat-icon">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 1 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>
                    </div>
                    <div>
                        <strong id="splash-stat-destinasi">0</strong>
                        <span>Destinasi Wisata</span>
                    </div>
                </div>
                <div class="splash-stat-card glass-card">
                    <div class="splash-stat-icon">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>
                    </div>
                    <div>
                        <strong id="splash-stat-rating">0.0</strong>
                        <span>Rata-rata Rating</span>
                    </div>
                </div>
                <div class="splash-stat-card glass-card">
                    <div class="splash-stat-icon">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 21h18"></path><path d="M5 21V7l8-4v18"></path><path d="M19 21V11l-6-4"></path></svg>
                    </div>
                    <div>
                        <strong id="splash-stat-kecamatan">0</strong>
                        <span>Kecamatan Tercakup</span>
                    </div>
                </div>
            </div>
        </div>
        <div class="splash-scroll-indicator">
            <div class="scroll-mouse"><div class="scroll-wheel"></div></div>
            <span>Scroll ke bawah</span>
        </div>
    </section>

    <!-- ========== FITUR ========== -->
    <section class="splash-section" id="features">
        <div class="tm-shell">
            <div class="splash-section-head" data-anim="fadeUp">
                <div class="splash-kicker">✦ Fitur Unggulan</div>
                <h2>Eksplorasi Wisata <span class="gradient-text">Lebih Mudah</span><br>dengan Teknologi GIS</h2>
                <p>Platform pemetaan modern yang memudahkan kamu menemukan destinasi wisata terbaik di Medan dan Deli Serdang.</p>
            </div>

            <div class="splash-features-grid">
                <div class="splash-feature-card glass-card" data-anim="fadeUp" data-delay="0">
                    <div class="feature-icon-wrap">
                        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6"></polygon><line x1="8" y1="2" x2="8" y2="18"></line><line x1="16" y1="6" x2="16" y2="22"></line></svg>
                    </div>
                    <h3>Peta Interaktif</h3>
                    <p>Peta berbasis Leaflet &amp; OpenStreetMap dengan marker kategori, clustering, dan navigasi rute langsung ke destinasi.</p>
                </div>
                <div class="splash-feature-card glass-card" data-anim="fadeUp" data-delay="100">
                    <div class="feature-icon-wrap">
                        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
                    </div>
                    <h3>Filter &amp; Pencarian</h3>
                    <p>Cari destinasi berdasarkan nama, kategori, rating, harga tiket, kecamatan, kelurahan, dan fasilitas.</p>
                </div>
                <div class="splash-feature-card glass-card" data-anim="fadeUp" data-delay="200">
                    <div class="feature-icon-wrap">
                        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s-8-4.5-8-11.8A8 8 0 0 1 12 2a8 8 0 0 1 8 8.2c0 7.3-8 11.8-8 11.8z"></path><circle cx="12" cy="10" r="3"></circle></svg>
                    </div>
                    <h3>Batas Wilayah</h3>
                    <p>Visualisasi batas administrasi Kota Medan dan Kab. Deli Serdang hingga level kelurahan dengan polygon PostGIS.</p>
                </div>
                <div class="splash-feature-card glass-card" data-anim="fadeUp" data-delay="300">
                    <div class="feature-icon-wrap">
                        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>
                    </div>
                    <h3>Kontribusi Komunitas</h3>
                    <p>Pengguna mobile dapat mengajukan lokasi wisata baru yang langsung divalidasi oleh admin web.</p>
                </div>

                <div class="splash-feature-card glass-card" data-anim="fadeUp" data-delay="500">
                    <div class="feature-icon-wrap">
                        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon></svg>
                    </div>
                    <h3>Review &amp; Rating</h3>
                    <p>Sistem ulasan dan rating dari pengunjung untuk setiap destinasi wisata yang telah terdaftar di platform.</p>
                </div>
            </div>
        </div>
    </section>

    <!-- ========== CARA KERJA ========== -->
    <section class="splash-section splash-section-alt" id="how-it-works">
        <div class="tm-shell">
            <div class="splash-section-head" data-anim="fadeUp">
                <div class="splash-kicker">◈ Cara Kerja</div>
                <h2>Tiga Langkah Mudah<br>Menemukan Destinasi Impianmu</h2>
            </div>
            <div class="splash-steps-grid">
                <div class="splash-step-card" data-anim="fadeUp" data-delay="0">
                    <div class="step-number">01</div>
                    <h3>Buka Peta</h3>
                    <p>Akses peta interaktif yang menampilkan seluruh destinasi wisata di Medan dan Deli Serdang secara real-time.</p>
                </div>
                <div class="splash-step-connector" data-anim="fadeUp" data-delay="100">
                    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
                </div>
                <div class="splash-step-card" data-anim="fadeUp" data-delay="200">
                    <div class="step-number">02</div>
                    <h3>Filter &amp; Jelajahi</h3>
                    <p>Gunakan filter kategori, lokasi, rating, dan fasilitas untuk menemukan destinasi sesuai keinginanmu.</p>
                </div>
                <div class="splash-step-connector" data-anim="fadeUp" data-delay="300">
                    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
                </div>
                <div class="splash-step-card" data-anim="fadeUp" data-delay="400">
                    <div class="step-number">03</div>
                    <h3>Navigasi &amp; Kunjungi</h3>
                    <p>Dapatkan rute navigasi dari lokasimu ke destinasi pilihan langsung melalui peta web.</p>
                </div>
            </div>
        </div>
    </section>

    <!-- ========== AREA CAKUPAN ========== -->
    <section class="splash-section" id="coverage">
        <div class="tm-shell">
            <div class="splash-section-head" data-anim="fadeUp">
                <div class="splash-kicker">◉ Area Cakupan</div>
                <h2>Dua Wilayah Utama<br>di Sumatera Utara</h2>
            </div>
            <div class="splash-coverage-grid">
                <div class="splash-coverage-card glass-card" data-anim="fadeUp" data-delay="0">
                    <div class="coverage-badge medan">Kota</div>
                    <h3>Kota Medan</h3>
                    <p>Ibu kota Provinsi Sumatera Utara dengan beragam destinasi wisata sejarah, budaya, kuliner, dan wisata modern.</p>
                    <ul class="coverage-tags">
                        <li>21 Kecamatan</li>
                        <li>Wisata Sejarah</li>
                        <li>Kuliner Legendaris</li>
                    </ul>
                </div>
                <div class="splash-coverage-card glass-card" data-anim="fadeUp" data-delay="200">
                    <div class="coverage-badge deli">Kabupaten</div>
                    <h3>Kab. Deli Serdang</h3>
                    <p>Kabupaten yang mengelilingi Kota Medan, kaya akan wisata alam, air terjun, perkebunan, dan destinasi keluarga.</p>
                    <ul class="coverage-tags">
                        <li>22 Kecamatan</li>
                        <li>Wisata Alam</li>
                        <li>Air Terjun</li>
                    </ul>
                </div>
            </div>
        </div>
    </section>

    <!-- ========== CTA ========== -->
    <section class="splash-cta-section">
        <div class="tm-shell">
            <div class="splash-cta-inner" data-anim="fadeUp">
                <h2>Siap Menjelajahi<br>Wisata Terbaik?</h2>
                <p>Buka peta interaktif sekarang dan temukan destinasi wisata favoritmu di Kota Medan dan Kabupaten Deli Serdang.</p>
                <div class="splash-cta-actions">
                    <a href="/peta" class="splash-cta-primary large">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6"></polygon><line x1="8" y1="2" x2="8" y2="18"></line><line x1="16" y1="6" x2="16" y2="22"></line></svg>
                        Buka Peta Sekarang
                    </a>
                    <a href="/explore" class="splash-cta-secondary">
                        Lihat Statistik Beranda
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
                    </a>
                </div>
            </div>
        </div>
    </section>

    <!-- ========== FOOTER ========== -->
    <footer class="splash-footer">
        <div class="tm-shell splash-footer-inner">
            <div class="splash-footer-brand">
                <div class="splash-brand-mark small">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 1 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>
                </div>
                <span>Tourscape MS</span>
            </div>
            <p>&copy; 2026 Tourscape MS &mdash; Pemetaan Wisata Kota Medan &amp; Kab. Deli Serdang</p>
        </div>
    </footer>

    <script src="/js/splash.js"></script>
</body>
</html>
