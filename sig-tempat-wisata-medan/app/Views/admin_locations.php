<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Halaman kelola lokasi wisata admin web untuk mengelola data approved yang tampil di peta publik.">
    <title>Kelola Lokasi Wisata - Admin Portal</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <link rel="stylesheet" href="<?= base_url('css/terra-medan.css') ?>?v=3.0">
    <link rel="stylesheet" href="<?= base_url('css/admin.css') ?>?v=3.0">
    <link rel="stylesheet" href="<?= base_url('css/stitch-pages.css') ?>?v=3.0">
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
    <?= view('layout/navbar', ['activePage' => 'admin']) ?>

    <main class="admin-extra-main">
        <div class="tm-shell">
            <section class="admin-extra-hero hero-panel">
                <div>
                    <span class="tm-kicker">Manage Locations</span>
                    <h2>Kelola lokasi wisata yang sudah aktif di sistem publik.</h2>
                    <p>
                        Halaman ini berfokus pada data wisata approved. Dari sini admin web dapat mencari,
                        melihat detail, memperbarui data, dan menghapus lokasi yang sudah tayang.
                    </p>
                </div>
                <div class="admin-extra-hero-actions">
                    <a href="/admin" class="tm-btn tm-btn-primary">Kembali ke Dashboard</a>
                    <a href="/peta" class="tm-btn tm-btn-secondary">Buka Peta Publik</a>
                </div>
            </section>

            <section class="admin-grid">
                <div class="admin-summary-grid">
                    <div class="admin-highlight-card">
                        <span>Total Approved</span>
                        <strong id="manage-stat-total">0</strong>
                        <div style="color:var(--text-secondary);">Jumlah lokasi aktif yang sudah tampil di publik.</div>
                    </div>
                    <div class="admin-highlight-card">
                        <span>Kategori Aktif</span>
                        <strong id="manage-stat-kategori">0</strong>
                        <div style="color:var(--text-secondary);">Sebaran kategori dari data wisata approved.</div>
                    </div>
                    <div class="admin-highlight-card">
                        <span>Rata-rata Rating</span>
                        <strong id="manage-stat-rating">0.0</strong>
                        <div style="color:var(--text-secondary);">Dihitung dari data rating yang tersimpan.</div>
                    </div>
                </div>

                <section class="admin-data-card">
                    <div class="section-head">
                        <div>
                            <span class="tm-kicker">Approved Data</span>
                            <h3>Daftar lokasi yang bisa dikelola</h3>
                            <p>Gunakan pencarian dan filter untuk memfokuskan daftar lokasi.</p>
                        </div>
                    </div>

                    <div class="admin-controls">
                        <div class="search-shell">
                            <svg class="search-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <circle cx="11" cy="11" r="8"></circle>
                                <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
                            </svg>
                            <input id="manage-search" class="tm-input" type="text" placeholder="Cari nama lokasi, kecamatan, atau kelurahan...">
                        </div>
                        <select id="manage-category" class="tm-select">
                            <option value="">Semua Kategori</option>
                        </select>
                        <select id="manage-sort" class="tm-select">
                            <option value="latest">Urutkan: Terbaru</option>
                            <option value="name">Urutkan: Nama A-Z</option>
                            <option value="rating">Urutkan: Rating Tertinggi</option>
                        </select>
                    </div>

                    <div class="table-shell">
                        <table class="terra-table">
                            <thead>
                                <tr>
                                    <th>Nama Lokasi</th>
                                    <th>Alamat</th>
                                    <th>Kecamatan</th>
                                    <th>Koordinat</th>
                                    <th>Kategori</th>
                                    <th>Rating</th>
                                    <th style="text-align:right;">Aksi</th>
                                </tr>
                            </thead>
                            <tbody id="manage-locations-body">
                                <tr>
                                    <td colspan="7">
                                        <div class="loading-panel">Memuat data approved...</div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </section>
            </section>
        </div>
    </main>

    <div class="modal-overlay" id="detail-modal">
        <div class="modal-container modal-lg tm-card">
            <div class="modal-header">
                <h2 id="detail-title">Detail Wisata</h2>
                <button class="modal-close" onclick="closeManageModal('detail-modal')" title="Tutup detail">&times;</button>
            </div>
            <div class="modal-body" id="detail-body"></div>
        </div>
    </div>

    <div class="modal-overlay" id="edit-modal">
        <div class="modal-container modal-xl tm-card">
            <div class="modal-header">
                <h2 id="edit-title">Edit Wisata</h2>
                <button class="modal-close" onclick="closeManageModal('edit-modal')" title="Tutup form">&times;</button>
            </div>
            <div class="modal-body">
                <form id="edit-form" onsubmit="saveManageEdit(event)">
                    <input type="hidden" id="edit-id">
                    <div class="form-grid">
                        <div class="form-group full">
                            <label>Nama Tempat *</label>
                            <input type="text" id="edit-nama" required>
                        </div>
                        <div class="form-group full">
                            <label>Deskripsi</label>
                            <textarea id="edit-deskripsi" rows="3"></textarea>
                        </div>
                        <div class="form-group">
                            <label>Kategori</label>
                            <input type="text" id="edit-kategori">
                        </div>
                        <div class="form-group">
                            <label>Target Pengunjung</label>
                            <select id="edit-target">
                                <option value="">-</option>
                                <option value="umum">Umum</option>
                                <option value="keluarga">Keluarga</option>
                                <option value="anak-anak">Anak-anak</option>
                                <option value="remaja">Remaja</option>
                                <option value="dewasa">Dewasa</option>
                            </select>
                        </div>
                        <div class="form-group full">
                            <label>Alamat</label>
                            <input type="text" id="edit-alamat">
                        </div>
                        <div class="form-group">
                            <label>Kecamatan</label>
                            <input type="text" id="edit-kecamatan">
                        </div>
                        <div class="form-group">
                            <label>Kelurahan</label>
                            <input type="text" id="edit-kelurahan">
                        </div>
                        <div class="form-group">
                            <label>Jam Buka</label>
                            <input type="time" id="edit-jam-buka">
                        </div>
                        <div class="form-group">
                            <label>Jam Tutup</label>
                            <input type="time" id="edit-jam-tutup">
                        </div>
                        <div class="form-group">
                            <label>Hari Operasional</label>
                            <input type="text" id="edit-hari" placeholder="Senin - Minggu">
                        </div>
                        <div class="form-group">
                            <label>Harga Tiket</label>
                            <input type="number" id="edit-harga" min="0">
                        </div>
                        <div class="form-group full">
                            <label>Keterangan Harga</label>
                            <input type="text" id="edit-ket-harga">
                        </div>
                        <div class="form-group">
                            <label>No. Telepon</label>
                            <input type="text" id="edit-telp">
                        </div>
                        <div class="form-group full">
                            <label>URL Foto <small>(Pisahkan dengan koma jika lebih dari satu)</small></label>
                            <textarea id="edit-foto" rows="2" placeholder="https://..."></textarea>
                        </div>
                        <div class="form-group">
                            <label>Rating (1-5)</label>
                            <input type="number" id="edit-rating" min="0" max="5" step="0.1" placeholder="0">
                        </div>
                        <div class="form-group full">
                            <label>Fasilitas</label>
                            <div class="checkbox-row">
                                <label><input type="checkbox" id="edit-toilet"> Toilet</label>
                                <label><input type="checkbox" id="edit-parkir"> Parkir</label>
                                <label><input type="checkbox" id="edit-mushola"> Mushola</label>
                                <label><input type="checkbox" id="edit-wifi"> WiFi</label>
                                <label><input type="checkbox" id="edit-tempat-makan"> Tempat Makan</label>
                                <label><input type="checkbox" id="edit-area-bermain"> Area Bermain</label>
                            </div>
                        </div>
                        <div class="form-group full">
                            <label>Lokasi Koordinat <small>(Klik atau geser marker pada peta)</small></label>
                            <div class="coord-row">
                                <input type="text" id="edit-lat" placeholder="Latitude" step="any">
                                <input type="text" id="edit-lng" placeholder="Longitude" step="any">
                            </div>
                            <div id="edit-map" class="edit-map"></div>
                        </div>
                    </div>
                    <div class="form-actions">
                        <button type="button" class="btn-cancel" onclick="closeManageModal('edit-modal')">Batal</button>
                        <button type="submit" class="btn-save">Simpan Perubahan</button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script src="<?= base_url('js/admin_locations.js') ?>"></script>
</body>
</html>
