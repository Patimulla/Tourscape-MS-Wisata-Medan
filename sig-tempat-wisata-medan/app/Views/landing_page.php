<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Beranda Tourscape MS untuk menjelajahi destinasi unggulan, statistik, dan akses cepat ke peta interaktif.">
    <title>Beranda - Tourscape MS</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="<?= base_url('css/terra-medan.css') ?>?v=3.0">
    <link rel="stylesheet" href="<?= base_url('css/stitch-pages.css') ?>?v=4.0">
</head>
<body class="site-page explore-page">
    <script>
        (function() {
            const saved = localStorage.getItem('terra-dark-mode');
            if (saved === 'true') {
                document.body.classList.add('dark');
            }
        })();
    </script>

    <?= view('layout/navbar', ['activePage' => 'explore']) ?>

    <main class="site-main">
        <div class="tm-shell" style="position:relative;">
            <div class="tm-orb tm-orb-teal" style="width:300px;height:300px;top:-80px;right:-60px;"></div>
            <div class="tm-orb tm-orb-emerald" style="width:200px;height:200px;bottom:200px;left:-80px;animation-delay:3s;"></div>
            <section class="hero-panel landing-hero section-shell" data-anim="fadeUp">
                <div>
                    <span class="tm-kicker">Explore Medan &amp; Deli Serdang</span>
                    <h2>Semua yang Kamu <span class="accent-glow-text">Butuhkan</span> untuk Menjelajahi <span class="gradient-text-earth">Wisata</span></h2>
                    <p>
                        GeoWisata menyatukan data tempat wisata yang sudah tervalidasi ke dalam peta interaktif berbasis Leaflet dan OpenStreetMap.
                        Jelajahi lokasi terbaru, baca ringkasan destinasi, lalu lanjutkan ke peta untuk melihat posisi sebenarnya.
                    </p>
                                        <div class="hero-actions">
                        <a href="/peta" class="tm-btn tm-btn-primary">Buka Peta Interaktif</a>
                    </div>
                </div>

                <div class="hero-visual">
                    <div>
                        <span class="tm-kicker" style="color: rgba(255,255,255,0.82);">Sistem Terhubung</span>
                        <h3 style="font-size: 1.8rem; margin-top: 8px;">Data mobile, validasi web, dan peta publik dalam satu alur.</h3>
                    </div>
                    <div class="hero-visual-grid">
                        <div class="hero-visual-card">
                            <span class="tm-kicker" style="color: rgba(255,255,255,0.82);">Public Map</span>
                            <strong id="landing-hero-total">0</strong>
                            <div>destinasi aktif</div>
                        </div>
                        <div class="hero-visual-card">
                            <span class="tm-kicker" style="color: rgba(255,255,255,0.82);">Coverage</span>
                            <strong id="landing-hero-kecamatan">0</strong>
                            <div>kecamatan tercakup</div>
                        </div>
                    </div>
                </div>
            </section>

            <section class="section-shell" data-anim="fadeUp">
                <div class="section-head">
                    <div>
                        <span class="tm-kicker">Overview</span>
                        <h3>Statistik <span class="gradient-text-earth">Wisata</span></h3>
                        <p>Ringkasan data aktif yang sudah tampil di sistem publik saat ini.</p>
                    </div>
                </div>
                <div class="stats-grid">
                    <div class="stats-card">
                        <div class="stats-card-icon">
                            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 1 1 18 0z"></path>
                                <circle cx="12" cy="10" r="3"></circle>
                            </svg>
                        </div>
                        <strong id="landing-stat-total">0</strong>
                        <span>Total Destinasi</span>
                    </div>
                    <div class="stats-card">
                        <div class="stats-card-icon">
                            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon>
                            </svg>
                        </div>
                        <strong id="landing-stat-rating">0.0</strong>
                        <span>Rata-rata Rating</span>
                    </div>
                    <div class="stats-card">
                        <div class="stats-card-icon">
                            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M3 21h18"></path>
                                <path d="M5 21V7l8-4v18"></path>
                                <path d="M19 21V11l-6-4"></path>
                            </svg>
                        </div>
                        <strong id="landing-stat-kecamatan">0</strong>
                        <span>Kecamatan Tercakup</span>
                    </div>
                    <div class="stats-card">
                        <div class="stats-card-icon">
                            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <rect x="3" y="3" width="7" height="7"></rect>
                                <rect x="14" y="3" width="7" height="7"></rect>
                                <rect x="14" y="14" width="7" height="7"></rect>
                                <rect x="3" y="14" width="7" height="7"></rect>
                            </svg>
                        </div>
                        <strong id="landing-stat-kategori">0</strong>
                        <span>Kategori Aktif</span>
                    </div>
                </div>
            </section>

            <section class="section-shell" data-anim="fadeUp" data-delay="100">
                <div class="section-head">
                    <div>
                        <span class="tm-kicker">Kategori Populer</span>
                        <h3>Eksplorasi Berdasarkan <span class="gradient-text-earth">Tema Wisata</span></h3>
                        <p>Pilih kategori untuk langsung membuka peta dengan konteks yang relevan.</p>
                    </div>
                </div>
                <div id="landing-category-pills" class="category-pills">
                    <span class="tm-chip">Memuat kategori...</span>
                </div>
            </section>

            <section class="section-shell" data-anim="fadeUp" data-delay="200">
                <div class="section-head">
                    <div>
                        <span class="tm-kicker">Destinasi Populer</span>
                        <h3>Destinasi <span class="gradient-text-earth">Wisata Populer</span></h3>
                        <p>Klik salah satu card untuk membuka detail lokasinya langsung di peta interaktif.</p>
                    </div>
                    <div class="destination-slider-actions">
                        <button type="button" class="destination-slider-btn" id="landing-destination-prev" aria-label="Geser ke kiri">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polyline points="15 18 9 12 15 6"></polyline>
                            </svg>
                        </button>
                        <button type="button" class="destination-slider-btn" id="landing-destination-next" aria-label="Geser ke kanan">
                            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polyline points="9 18 15 12 9 6"></polyline>
                            </svg>
                        </button>
                        <a href="/peta" class="tm-btn tm-btn-ghost">Lihat Semua di Peta</a>
                    </div>
                </div>

                <div class="destination-slider-wrapper">
                    <div id="landing-destination-grid" class="destination-carousel">
                        <div class="destination-card" style="padding:16px;">
                            <div class="loading-panel">Memuat destinasi...</div>
                        </div>
                    </div>
                </div>
            </section>
        </div>
    </main>

    <script src="<?= base_url('js/landing_page.js') ?>"></script>
</body>
</html>
