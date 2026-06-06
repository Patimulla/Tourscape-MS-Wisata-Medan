<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Tourscape MS - peta interaktif destinasi wisata berbasis Leaflet dan OpenStreetMap.">
    <title>Tourscape MS</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
          integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
          crossorigin="">
    <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css">
    <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css">
    <link rel="stylesheet" href="https://unpkg.com/leaflet-routing-machine@latest/dist/leaflet-routing-machine.css">

    <link rel="stylesheet" href="/css/terra-medan.css?v=3.0">
    <link rel="stylesheet" href="/css/stitch-pages.css?v=4.0">
    <link rel="stylesheet" href="/css/webgis.css?v=4.0">
</head>
<body class="webgis-page">
    <script>
        (function() {
            const saved = localStorage.getItem('terra-dark-mode');
            if (saved === 'true') {
                document.body.classList.add('dark');
            }
        })();
    </script>

    <?= view('layout/navbar', ['activePage' => 'peta', 'headerId' => 'app-header', 'headerClass' => 'webgis-topbar', 'innerClass' => 'webgis-topbar-inner']) ?>

    <main id="app-main" class="webgis-stage">
        <aside id="sidebar" class="sidebar tm-card">
            <div class="sidebar-body">
                <div class="sidebar-toolbar">
                    <label class="tm-sr-only" for="search-input">Cari tempat wisata</label>
                    <div class="search-shell sidebar-search-shell">
                        <svg class="search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <circle cx="11" cy="11" r="8"></circle>
                            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
                        </svg>
                        <input type="text" id="search-input" class="tm-input" placeholder="Search locations..." autocomplete="off">
                    </div>

                    <button class="btn-adv-filter compact" id="btn-adv-filter" type="button" aria-expanded="false" title="Advanced Filter">
                        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"></polygon>
                        </svg>
                    </button>

                    <button id="btn-toggle-sidebar" class="btn-toggle" type="button" title="Sembunyikan panel">
                        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <polyline points="15 18 9 12 15 6"></polyline>
                        </svg>
                    </button>
                </div>

                <section id="adv-filter-panel" class="sidebar-block adv-filter-popover">
                    <div class="adv-filter-head">
                        <strong>Advanced Filter</strong>
                        <button id="btn-reset-filters" class="adv-filter-reset" type="button">Reset</button>
                    </div>
                    <div class="form-stack">
                        <div class="filter-grid-two">
                            <div class="form-field">
                                <label for="filter-kategori">Kategori</label>
                                <select id="filter-kategori" class="tm-select">
                                    <option value="">Semua Kategori</option>
                                </select>
                            </div>
                            <div class="form-field">
                                <label for="filter-rating">Rating</label>
                                <select id="filter-rating" class="tm-select">
                                    <option value="0">Semua Rating</option>
                                    <option value="3">★ 3.0+</option>
                                    <option value="4">★ 4.0+</option>
                                    <option value="4.5">★ 4.5+</option>
                                </select>
                            </div>
                        </div>

                        <div class="form-field">
                            <label for="filter-top-level-wilayah">Kota / Kabupaten</label>
                            <select id="filter-top-level-wilayah" class="tm-select">
                                <option value="">Pilih area utama terlebih dahulu</option>
                            </select>
                        </div>

                        <label class="toggle-row" for="toggle-all-kecamatan">
                            <input type="checkbox" id="toggle-all-kecamatan">
                            <span>Semua kecamatan</span>
                        </label>

                        <div class="form-field">
                            <label for="filter-kecamatan-visual">Kecamatan</label>
                            <select id="filter-kecamatan-visual" class="tm-select">
                                <option value="">Pilih kota/kabupaten dulu</option>
                            </select>
                        </div>

                        <label class="toggle-row" for="toggle-all-leaf-wilayah">
                            <input type="checkbox" id="toggle-all-leaf-wilayah">
                            <span>Semua kelurahan / desa</span>
                        </label>

                        <div class="form-field">
                            <label for="filter-leaf-wilayah-visual">Kelurahan / Desa</label>
                            <select id="filter-leaf-wilayah-visual" class="tm-select">
                                <option value="">Pilih kecamatan dulu</option>
                            </select>
                        </div>

                        <label class="toggle-row" for="toggle-roads-kecamatan">
                            <input type="checkbox" id="toggle-roads-kecamatan">
                            <span>Tampilkan jalan</span>
                        </label>

                        <div class="filter-grid-two">
                            <div class="filter-group">
                                <label for="filter-harga">Harga Tiket</label>
                                <select id="filter-harga">
                                    <option value="all">Semua Harga</option>
                                    <option value="free">Gratis</option>
                                    <option value="paid">Berbayar</option>
                                </select>
                            </div>
                            <div class="filter-group">
                                <label for="filter-target">Target</label>
                                <select id="filter-target">
                                    <option value="">Semua Target</option>
                                    <option value="umum">Umum</option>
                                    <option value="keluarga">Keluarga</option>
                                    <option value="anak-anak">Anak-anak</option>
                                    <option value="remaja">Remaja</option>
                                    <option value="dewasa">Dewasa</option>
                                </select>
                            </div>
                        </div>

                        <div class="filter-group">
                            <label>Fasilitas</label>
                            <div class="checkbox-grid">
                                <label><input type="checkbox" class="filter-fasilitas" value="toilet"> Toilet</label>
                                <label><input type="checkbox" class="filter-fasilitas" value="parkir"> Parkir</label>
                                <label><input type="checkbox" class="filter-fasilitas" value="mushola"> Mushola</label>
                                <label><input type="checkbox" class="filter-fasilitas" value="wifi"> WiFi</label>
                                <label><input type="checkbox" class="filter-fasilitas" value="tempat_makan"> Tempat Makan</label>
                                <label><input type="checkbox" class="filter-fasilitas" value="area_bermain"> Area Bermain</label>
                            </div>
                        </div>

                        <button class="btn-apply-filter" type="button" onclick="applyFilters()">Terapkan Filter</button>
                    </div>
                </section>

                <section class="sidebar-results-shell">
                    <div class="sidebar-results-head">
                        <h2>Daftar Wisata</h2>
                        <div class="sidebar-mini-stats" id="sidebar-stats">
                            <span class="sidebar-mini-stat"><strong id="stat-total">0</strong><small>Total</small></span>
                            <span class="sidebar-mini-stat"><strong id="stat-showing">0</strong><small>Tampil</small></span>
                        </div>
                    </div>

                    <div class="sidebar-list tm-scrollbar" id="wisata-list">
                        <div class="loading-spinner">
                            <div class="spinner"></div>
                            <p>Memuat data wisata...</p>
                        </div>
                    </div>
                </section>
            </div>
        </aside>

        <section class="map-shell">
            <div id="map"></div>
        </section>

        <button id="btn-open-sidebar" class="btn-open-sidebar" title="Buka panel pencarian" style="display: none;">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="9 18 15 12 9 6"></polyline>
            </svg>
        </button>

        <button id="btn-mobile-sidebar" class="btn-mobile-sidebar" title="Menu panel">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="3" y1="12" x2="21" y2="12"></line>
                <line x1="3" y1="6" x2="21" y2="6"></line>
                <line x1="3" y1="18" x2="21" y2="18"></line>
            </svg>
        </button>
    </main>

    <div id="detail-modal" class="modal-overlay" style="display: none;">
        <div class="modal-content tm-card">
            <button id="btn-close-modal" class="modal-close" title="Tutup detail">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="18" y1="6" x2="6" y2="18"></line>
                    <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
            </button>
            <div id="modal-body"></div>
        </div>
    </div>

    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
            integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
            crossorigin=""></script>
    <script src="https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js"></script>
    <script src="https://unpkg.com/leaflet-routing-machine@latest/dist/leaflet-routing-machine.js"></script>
    <script src="/js/webgis.js"></script>
</body>
</html>


