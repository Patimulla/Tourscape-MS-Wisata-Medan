<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Portal admin web untuk validasi, pengelolaan, dan pemantauan data wisata Medan dan Deli Serdang.">
    <title>Admin Portal - Tourscape MS</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <link rel="stylesheet" href="/css/terra-medan.css?v=4.0">
    <link rel="stylesheet" href="/css/admin.css?v=4.0">
    <link rel="stylesheet" href="/css/stitch-pages.css?v=4.0">
</head>
<body class="admin-page-body">
    <script>
        (function() {
            const saved = localStorage.getItem('terra-dark-mode');
            if (saved === 'true') {
                document.body.classList.add('dark');
            }
        })();
    </script>

    <?= view('layout/navbar', ['activePage' => 'admin']) ?>

    <main class="admin-page">
        <div class="tm-shell admin-shell">
            <section class="admin-hero tm-card">
                <div class="admin-hero-copy">
                    <span class="tm-kicker">Dashboard Admin</span>
                    <h2>Kelola pengajuan mobile dan data wisata yang sudah aktif dalam satu workspace.</h2>
                    <p>Pengajuan dari admin mobile akan masuk ke tab pending. Setelah disetujui, data berpindah ke daftar approved dan tetap bisa dikelola dari web admin.</p>
                    <div class="admin-hero-actions">
                        <a href="/admin/kelola-lokasi" class="tm-btn tm-btn-primary">Kelola Lokasi Approved</a>
                        <a href="/peta" class="tm-btn tm-btn-secondary">Buka Peta Publik</a>
                        <a href="/" class="tm-btn tm-btn-ghost">Beranda Publik</a>
                    </div>
                </div>
            </section>

            <section class="dashboard-stats" id="dashboard-stats">
                <div class="stat-card">
                    <div class="stat-card-icon approved">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M20 6L9 17l-5-5"></path>
                        </svg>
                    </div>
                    <div class="stat-number" id="stat-total-approved">-</div>
                    <div class="stat-label">Wisata Approved</div>
                </div>
                <div class="stat-card pending">
                    <div class="stat-card-icon pending">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <circle cx="12" cy="12" r="10"></circle>
                            <polyline points="12 6 12 12 16 14"></polyline>
                        </svg>
                    </div>
                    <div class="stat-number" id="stat-total-pending">-</div>
                    <div class="stat-label">Menunggu Validasi</div>
                </div>
                <div class="stat-card">
                    <div class="stat-card-icon categories">
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <rect x="3" y="3" width="7" height="7"></rect>
                            <rect x="14" y="3" width="7" height="7"></rect>
                            <rect x="14" y="14" width="7" height="7"></rect>
                            <rect x="3" y="14" width="7" height="7"></rect>
                        </svg>
                    </div>
                    <div class="stat-number" id="stat-total-kategori">-</div>
                    <div class="stat-label">Kategori</div>
                </div>
            </section>

            <div class="tab-nav">
                <button class="tab-btn active" data-tab="pending" onclick="switchTab('pending')">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="10"></circle>
                        <polyline points="12 6 12 12 16 14"></polyline>
                    </svg>
                    <span>Menunggu Validasi</span>
                    <span class="tab-badge" id="tab-badge-pending">0</span>
                </button>
                <button class="tab-btn" data-tab="approved" onclick="switchTab('approved')">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M20 6L9 17l-5-5"></path>
                    </svg>
                    <span>Data Approved</span>
                </button>
            </div>

            <div class="admin-content">
                <section class="tab-content active" id="tab-pending">
                    <div class="section-intro">
                        <div class="tm-section-title">
                            <span class="tm-kicker">Submission Review</span>
                            <h3>Pengajuan dari admin mobile</h3>
                        </div>
                    </div>
                    <div class="pending-list" id="pending-list">
                        <div class="loading">
                            <div class="spinner"></div>
                            <p>Memuat data pending...</p>
                        </div>
                    </div>
                </section>

                <section class="tab-content" id="tab-approved">
                    <div class="approved-overview">
                        <section class="admin-directory-section tm-card">
                            <div class="section-head">
                                <div class="tm-section-title">
                                    <span class="tm-kicker">Admin Mobile</span>
                                    <h3>Filter berdasarkan akun pengaju</h3>
                                </div>
                            </div>
                            <div class="admin-directory-grid" id="admin-directory-grid">
                                <div class="loading">
                                    <div class="spinner"></div>
                                    <p>Memuat admin mobile...</p>
                                </div>
                            </div>
                        </section>

                        <section class="approved-data-shell tm-card">
                            <div class="section-head">
                                <div class="tm-section-title">
                                    <span class="tm-kicker">Approved Data</span>
                                    <h3>Daftar wisata aktif</h3>
                                </div>
                            </div>

                            <div class="approved-toolbar">
                                <div class="search-box">
                                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                        <circle cx="11" cy="11" r="8"></circle>
                                        <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
                                    </svg>
                                    <input type="text" id="approved-search" placeholder="Cari wisata approved..." oninput="filterApproved()">
                                </div>
                                <select id="approved-filter-kategori" onchange="filterApproved()">
                                    <option value="">Semua Kategori</option>
                                </select>
                                <select id="approved-filter-admin" onchange="filterApproved()">
                                    <option value="">Semua Pengaju</option>
                                </select>
                            </div>

                            <div class="table-wrapper">
                                <table class="data-table" id="approved-table">
                                    <thead>
                                        <tr>
                                            <th>No</th>
                                            <th>Nama Tempat</th>
                                            <th>Pengaju</th>
                                            <th>Kategori</th>
                                            <th>Kecamatan</th>
                                            <th>Kelurahan</th>
                                            <th>Rating</th>
                                            <th>Aksi</th>
                                        </tr>
                                    </thead>
                                    <tbody id="approved-tbody"></tbody>
                                </table>
                            </div>
                        </section>
                    </div>
                </section>
            </div>
        </div>
    </main>

    <div class="modal-overlay" id="detail-modal">
        <div class="modal-container modal-lg tm-card">
            <div class="modal-header">
                <h2 id="detail-title">Detail Wisata</h2>
                <button class="modal-close" onclick="closeModal('detail-modal')" title="Tutup detail">&times;</button>
            </div>
            <div class="modal-body" id="detail-body"></div>
        </div>
    </div>

    <div class="modal-overlay" id="edit-modal">
        <div class="modal-container modal-xl tm-card">
            <div class="modal-header">
                <h2 id="edit-title">Edit Wisata</h2>
                <button class="modal-close" onclick="closeModal('edit-modal')" title="Tutup form">&times;</button>
            </div>
            <div class="modal-body">
                <form id="edit-form" onsubmit="saveEdit(event)">
                    <input type="hidden" id="edit-id">
                    <div class="form-grid">
                        <div class="form-group full">
                            <label for="edit-nama">Nama Tempat *</label>
                            <input type="text" id="edit-nama" required>
                        </div>
                        <div class="form-group full">
                            <label for="edit-deskripsi">Deskripsi</label>
                            <textarea id="edit-deskripsi" rows="3"></textarea>
                        </div>
                        <div class="form-group">
                            <label for="edit-kategori">Kategori</label>
                            <select id="edit-kategori">
                                <option value="">Pilih Kategori</option>
                            </select>
                        </div>
                        <div class="form-group">
                            <label for="edit-target">Target Pengunjung</label>
                            <select id="edit-target">
                                <option value="">-</option>
                                <option value="umum">Umum</option>
                                <option value="keluarga">Keluarga</option>
                                <option value="anak-anak">Anak-anak</option>
                            </select>
                        </div>
                        <div class="form-group full">
                            <label for="edit-alamat">Alamat</label>
                            <input type="text" id="edit-alamat">
                        </div>
                        <div class="form-group">
                            <label for="edit-kota">Kota / Kabupaten</label>
                            <select id="edit-kota"></select>
                        </div>
                        <div class="form-group">
                            <label for="edit-kecamatan">Kecamatan</label>
                            <select id="edit-kecamatan"></select>
                        </div>
                        <div class="form-group">
                            <label for="edit-kelurahan">Kelurahan</label>
                            <select id="edit-kelurahan"></select>
                        </div>
                        <div class="form-group">
                            <label for="edit-jam-buka">Jam Buka</label>
                            <input type="time" id="edit-jam-buka">
                        </div>
                        <div class="form-group">
                            <label for="edit-jam-tutup">Jam Tutup</label>
                            <input type="time" id="edit-jam-tutup">
                        </div>
                        <div class="form-group">
                            <label>Hari Operasional</label>
                            <div class="edit-day-selector" id="edit-hari-selector">
                                <button type="button" class="edit-day-chip" data-day="Senin">Sen</button>
                                <button type="button" class="edit-day-chip" data-day="Selasa">Sel</button>
                                <button type="button" class="edit-day-chip" data-day="Rabu">Rab</button>
                                <button type="button" class="edit-day-chip" data-day="Kamis">Kam</button>
                                <button type="button" class="edit-day-chip" data-day="Jumat">Jum</button>
                                <button type="button" class="edit-day-chip" data-day="Sabtu">Sab</button>
                                <button type="button" class="edit-day-chip" data-day="Minggu">Min</button>
                            </div>
                        </div>
                        <div class="form-group">
                            <label for="edit-harga">Harga Tiket</label>
                            <input type="number" id="edit-harga" min="0">
                        </div>
                        <div class="form-group full">
                            <label for="edit-ket-harga">Keterangan Harga</label>
                            <input type="text" id="edit-ket-harga">
                        </div>
                        <div class="form-group">
                            <label for="edit-telp">No. Telepon</label>
                            <input type="text" id="edit-telp">
                        </div>
                        <div class="form-group full">
                            <label>Foto Lokasi</label>
                            <div class="edit-photo-manager" id="edit-photo-manager"></div>
                            <div class="edit-photo-extra">
                                <label for="edit-foto-extra" class="edit-photo-extra-label">Tambah Foto Baru</label>
                                <input type="file" id="edit-foto-extra" accept="image/*" multiple>
                            </div>
                        </div>
                        <div class="form-group">
                            <label for="edit-rating">Rating (1-5)</label>
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
                        <button type="button" class="btn-cancel" onclick="closeModal('edit-modal')">Batal</button>
                        <button type="submit" class="btn-save">Simpan Perubahan</button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <div class="modal-overlay" id="confirm-modal">
        <div class="modal-container modal-sm tm-card confirm-modal-card">
            <div class="modal-header">
                <h2 id="confirm-title">Konfirmasi Aksi</h2>
                <button class="modal-close" onclick="closeConfirmModal()" title="Tutup konfirmasi">&times;</button>
            </div>
            <div class="modal-body confirm-modal-body">
                <p class="confirm-message" id="confirm-message"></p>
                <div class="confirm-note-group" id="confirm-note-group" style="display:none;">
                    <label for="confirm-note-input">Catatan Admin</label>
                    <textarea id="confirm-note-input" rows="4" placeholder="Tulis alasan penolakan atau permintaan perbaikan..."></textarea>
                    <div class="confirm-note-error" id="confirm-note-error"></div>
                </div>
            </div>
            <div class="form-actions confirm-actions">
                <button type="button" class="btn-cancel" onclick="closeConfirmModal()">Batal</button>
                <button type="button" class="btn-save" id="confirm-submit-btn">Lanjutkan</button>
            </div>
        </div>
    </div>

    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script src="/js/admin.js"></script>
</body>
</html>
