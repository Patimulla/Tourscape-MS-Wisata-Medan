-- ============================================================
-- SIG WISATA KOTA MEDAN
-- Database: PostgreSQL + PostGIS
-- ============================================================

-- 1. Aktifkan ekstensi PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- 2. TABEL KATEGORI
-- ============================================================
CREATE TABLE kategori (
    id          SERIAL PRIMARY KEY,
    nama_kategori VARCHAR(100) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- 3. TABEL WISATA (utama)
-- ============================================================
CREATE TABLE wisata (
    id                SERIAL PRIMARY KEY,
    nama_tempat       VARCHAR(255) NOT NULL,
    deskripsi         TEXT,
    alamat            VARCHAR(500),
    kecamatan         VARCHAR(100),
    kelurahan         VARCHAR(100),
    geom              GEOMETRY(Point, 4326),       -- PostGIS
    kategori_id       INT NOT NULL,
    target_pengunjung VARCHAR(100),                 -- keluarga, anak-anak, umum
    jam_buka          TIME,
    jam_tutup         TIME,
    hari_operasional  VARCHAR(100),                 -- Senin-Minggu, dll
    harga_tiket       DECIMAL(12,2) DEFAULT 0,
    keterangan_harga  TEXT,
    no_telepon        VARCHAR(20),
    status            VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_wisata_kategori
        FOREIGN KEY (kategori_id) REFERENCES kategori(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Index spasial untuk performa query geom
CREATE INDEX idx_wisata_geom ON wisata USING GIST (geom);

-- Index pada status untuk filter cepat
CREATE INDEX idx_wisata_status ON wisata (status);

-- ============================================================
-- 4. TABEL FASILITAS
-- ============================================================
CREATE TABLE fasilitas (
    id              SERIAL PRIMARY KEY,
    nama_fasilitas  VARCHAR(100) NOT NULL UNIQUE
);

-- ============================================================
-- 5. TABEL RELASI WISATA_FASILITAS (many-to-many)
-- ============================================================
CREATE TABLE wisata_fasilitas (
    id            SERIAL PRIMARY KEY,
    wisata_id     INT NOT NULL,
    fasilitas_id  INT NOT NULL,

    CONSTRAINT fk_wf_wisata
        FOREIGN KEY (wisata_id) REFERENCES wisata(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_wf_fasilitas
        FOREIGN KEY (fasilitas_id) REFERENCES fasilitas(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uq_wisata_fasilitas
        UNIQUE (wisata_id, fasilitas_id)
);

-- ============================================================
-- 6. TABEL WISATA_FOTO
-- ============================================================
CREATE TABLE wisata_foto (
    id          SERIAL PRIMARY KEY,
    wisata_id   INT NOT NULL,
    foto_url    VARCHAR(500) NOT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_foto_wisata
        FOREIGN KEY (wisata_id) REFERENCES wisata(id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- 7. TABEL REVIEW
-- ============================================================
CREATE TABLE review (
    id              SERIAL PRIMARY KEY,
    wisata_id       INT NOT NULL,
    nama_reviewer   VARCHAR(150) NOT NULL,
    rating          INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    ulasan          TEXT,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_review_wisata
        FOREIGN KEY (wisata_id) REFERENCES wisata(id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================
-- 8. CONTOH INSERT DATA
-- ============================================================

-- 8a. Kategori
INSERT INTO kategori (nama_kategori) VALUES
    ('Taman'),
    ('Waterpark'),
    ('Kebun Binatang'),
    ('Museum'),
    ('Taman Bermain'),
    ('Danau'),
    ('Kuliner'),
    ('Religi');

-- 8b. Fasilitas default
INSERT INTO fasilitas (nama_fasilitas) VALUES
    ('Toilet'),
    ('Parkir'),
    ('Area Bermain Anak'),
    ('Tempat Makan'),
    ('Mushola'),
    ('WiFi');

-- 8c. Wisata (5 tempat di Medan)
INSERT INTO wisata (nama_tempat, deskripsi, alamat, kecamatan, kelurahan, geom, kategori_id, target_pengunjung, jam_buka, jam_tutup, hari_operasional, harga_tiket, keterangan_harga, no_telepon, status)
VALUES
(
    'Taman Sri Deli',
    'Taman kota bersejarah yang terletak di pusat Kota Medan, dikelilingi oleh bangunan kolonial dan Istana Maimun.',
    'Jl. Brigjen Katamso, Medan',
    'Medan Maimun',
    'Aur',
    ST_SetSRID(ST_MakePoint(98.6833, 3.5753), 4326),
    1, -- Taman
    'umum',
    '06:00', '22:00', 'Senin-Minggu',
    0, 'Gratis',
    '061-4567890',
    'approved'
),
(
    'Hairos Water Park',
    'Waterpark terbesar di Medan dengan berbagai wahana air dan kolam renang untuk keluarga.',
    'Jl. Jamin Ginting KM 14.5, Medan',
    'Medan Tuntungan',
    'Sidomulyo',
    ST_SetSRID(ST_MakePoint(98.6308, 3.5143), 4326),
    2, -- Waterpark
    'keluarga',
    '09:00', '17:00', 'Senin-Minggu',
    50000, 'Weekday. Weekend Rp 75.000',
    '061-8365789',
    'approved'
),
(
    'Kebun Binatang Medan (Medan Zoo)',
    'Kebun binatang tertua di Sumatera yang memiliki koleksi satwa nusantara dan mancanegara.',
    'Jl. Bunga Rampai II No.100, Medan',
    'Medan Tuntungan',
    'Simalingkar B',
    ST_SetSRID(ST_MakePoint(98.6125, 3.5357), 4326),
    3, -- Kebun Binatang
    'keluarga',
    '08:30', '17:00', 'Selasa-Minggu',
    30000, 'Anak-anak Rp 15.000',
    '061-8361111',
    'approved'
),
(
    'Museum Negeri Provinsi Sumatera Utara',
    'Museum yang menyimpan koleksi budaya, sejarah, dan arkeologi Sumatera Utara.',
    'Jl. H.M. Joni No.51, Medan',
    'Medan Area',
    'Teladan Barat',
    ST_SetSRID(ST_MakePoint(98.7005, 3.5780), 4326),
    4, -- Museum
    'umum',
    '08:00', '16:00', 'Selasa-Minggu',
    5000, 'Pelajar Rp 2.000',
    '061-7161886',
    'approved'
),
(
    'Istana Maimun',
    'Istana Kesultanan Deli yang merupakan ikon Kota Medan dan salah satu istana terindah di Indonesia.',
    'Jl. Brigjen Katamso No.66, Medan',
    'Medan Maimun',
    'Aur',
    ST_SetSRID(ST_MakePoint(98.6837, 3.5757), 4326),
    8, -- Religi/Heritage
    'umum',
    '08:00', '17:00', 'Senin-Minggu',
    10000, 'Termasuk foto kostum adat',
    '061-4516111',
    'approved'
);

-- 8d. Wisata Fasilitas
-- Taman Sri Deli: Toilet, Parkir, Mushola
INSERT INTO wisata_fasilitas (wisata_id, fasilitas_id) VALUES (1, 1), (1, 2), (1, 5);
-- Hairos Water Park: Semua fasilitas
INSERT INTO wisata_fasilitas (wisata_id, fasilitas_id) VALUES (2, 1), (2, 2), (2, 3), (2, 4), (2, 5), (2, 6);
-- Medan Zoo: Toilet, Parkir, Area Bermain Anak, Tempat Makan
INSERT INTO wisata_fasilitas (wisata_id, fasilitas_id) VALUES (3, 1), (3, 2), (3, 3), (3, 4);
-- Museum: Toilet, Parkir
INSERT INTO wisata_fasilitas (wisata_id, fasilitas_id) VALUES (4, 1), (4, 2);
-- Istana Maimun: Toilet, Parkir, Mushola
INSERT INTO wisata_fasilitas (wisata_id, fasilitas_id) VALUES (5, 1), (5, 2), (5, 5);

-- 8e. Foto
INSERT INTO wisata_foto (wisata_id, foto_url) VALUES
    (1, 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/Taman_Sri_Deli_Medan.jpg/800px-Taman_Sri_Deli_Medan.jpg'),
    (2, 'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/0b/4d/5e/66/hairos-waterpark.jpg'),
    (3, 'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/13/e4/07/74/medan-zoo.jpg'),
    (4, 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Museum_Negeri_Medan.jpg/800px-Museum_Negeri_Medan.jpg'),
    (5, 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Istana_Maimun_Medan.jpg/800px-Istana_Maimun_Medan.jpg');

-- 8f. Review
INSERT INTO review (wisata_id, nama_reviewer, rating, ulasan) VALUES
    (1, 'Ahmad Rizki', 4, 'Taman yang asri dan nyaman untuk bersantai di tengah kota. Cocok untuk jogging pagi.'),
    (1, 'Siti Aminah', 5, 'Tempat favorit saya untuk bersantai. Pemandangan Istana Maimun sangat indah dari sini.'),
    (2, 'Budi Santoso', 4, 'Wahana air yang seru untuk keluarga. Anak-anak sangat senang bermain di sini.'),
    (2, 'Dewi Lestari', 3, 'Lumayan untuk liburan keluarga, tapi perlu renovasi di beberapa area.'),
    (3, 'Rudi Hartono', 4, 'Koleksi hewannya cukup lengkap. Orangutan Sumatera menjadi daya tarik utama.'),
    (3, 'Linda Sari', 5, 'Anak-anak sangat suka! Banyak hewan yang bisa dilihat dari dekat.'),
    (4, 'Eko Prasetyo', 4, 'Museum yang kaya akan sejarah Sumatera Utara. Koleksi artefak Batak sangat menarik.'),
    (5, 'Maria Tampubolon', 5, 'Arsitektur istana yang mengagumkan. Wajib dikunjungi jika ke Medan!'),
    (5, 'Fajar Hidayat', 4, 'Bisa foto pakai baju adat Melayu. Pengalaman yang unik dan berkesan.');
