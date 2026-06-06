<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Detail destinasi wisata publik Tourscape MS.">
    <title>Detail Lokasi - Tourscape MS</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
          integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
          crossorigin="">
    <link rel="stylesheet" href="/css/terra-medan.css?v=3.0">
    <link rel="stylesheet" href="/css/stitch-pages.css?v=3.0">
</head>
<body class="site-page">
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
            <div class="tm-orb tm-orb-teal" style="width:250px;height:250px;top:-60px;right:-50px;"></div>
            <div id="detail-loading" class="loading-panel page-panel">Memuat detail lokasi...</div>

            <div id="detail-shell" class="detail-shell hidden">
                <section class="detail-hero hero-panel">
                    <img id="detail-hero-image" class="detail-hero-image" alt="Foto destinasi">
                    <div class="detail-hero-overlay"></div>
                    <div class="detail-hero-content">
                        <div class="detail-chip-row">
                            <span id="detail-category-chip" class="tm-chip">Kategori</span>
                            <span id="detail-rating-chip" class="tm-chip">Rating</span>
                        </div>
                        <h2 id="detail-title">Nama Lokasi</h2>
                        <p id="detail-address" class="detail-hero-subtitle">Alamat lengkap destinasi</p>
                    </div>
                </section>

                <aside class="detail-floating-card">
                    <div class="tm-kicker">Aksi Cepat</div>
                    <h3 id="detail-side-title" style="font-size:1.3rem; margin-top:8px; color:var(--tm-primary);">Destinasi</h3>
                    <p id="detail-side-subtitle" style="color:var(--text-secondary); margin-top:8px; line-height:1.7;">Ringkasan singkat lokasi wisata.</p>

                    <div class="detail-actions">
                        <a id="detail-open-map" href="/peta" class="tm-btn tm-btn-primary">Lihat di Peta</a>
                        <button id="detail-copy-address" type="button" class="tm-btn tm-btn-secondary">Salin Alamat</button>
                    </div>

                    <div class="detail-section">
                        <h3>Informasi Inti</h3>
                        <div id="detail-info-grid" class="detail-info-grid"></div>
                    </div>

                    <div class="detail-section">
                        <h3>Peta Lokasi</h3>
                        <div id="detail-inline-map" class="detail-map"></div>
                    </div>
                </aside>
            </div>

            <div id="detail-sections" class="hidden" style="margin-top:24px;" data-anim="fadeUp">
                <section class="page-panel" style="padding:24px;">
                    <div class="detail-section" style="margin-top:0;">
                        <h3>Tentang Destinasi</h3>
                        <p id="detail-description">Deskripsi destinasi.</p>
                    </div>
                </section>

                <section class="page-panel" style="padding:24px; margin-top:22px;">
                    <div class="detail-section" style="margin-top:0;">
                        <h3>Fasilitas Tersedia</h3>
                        <div id="detail-facilities" class="facility-grid"></div>
                    </div>
                </section>

                <section class="page-panel" style="padding:24px; margin-top:22px;">
                    <div class="detail-section" style="margin-top:0;">
                        <h3>Galeri Foto</h3>
                        <div id="detail-gallery" class="detail-gallery-grid"></div>
                    </div>
                </section>

                <section class="page-panel" style="padding:24px; margin-top:22px;">
                    <div class="detail-section" style="margin-top:0;">
                        <h3>Ulasan Pengunjung</h3>
                        <div id="detail-reviews" class="review-list"></div>
                    </div>
                </section>
            </div>

            <div id="detail-error" class="empty-panel hidden" style="margin-top:22px;">
                Data wisata tidak ditemukan atau gagal dimuat.
            </div>
        </div>
    </main>

    <script>
        window.WISATA_DETAIL_ID = <?= json_encode($wisataId) ?>;
    </script>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
            integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
            crossorigin=""></script>
    <script src="/js/wisata_detail_page.js"></script>
</body>
</html>
