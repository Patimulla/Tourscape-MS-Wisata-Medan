<?php

namespace App\Models;

use CodeIgniter\Model;

/**
 * WisataModel — disesuaikan dengan tabel `wisata` di database gis_wisata
 *
 * Struktur tabel:
 *   id, nama_tempat, deskripsi, alamat, kecamatan, kelurahan,
 *   kategori (varchar), target_pengunjung,
 *   toilet (bool), parkir (bool), area_bermain (bool),
 *   tempat_makan (bool), mushola (bool), wifi (bool),
 *   jam_buka (time), jam_tutup (time), hari_operasional,
 *   harga_tiket (numeric), keterangan_harga,
 *   foto (varchar), rating (float), no_telepon,
 *   geom (geometry Point 4326)
 */
class WisataModel extends Model
{
    protected $table         = 'wisata';
    protected $primaryKey    = 'id';
    protected $allowedFields = [
        'nama_tempat', 'deskripsi', 'alamat', 'kecamatan', 'kelurahan',
        'kategori', 'target_pengunjung',
        'toilet', 'parkir', 'area_bermain', 'tempat_makan', 'mushola', 'wifi',
        'jam_buka', 'jam_tutup', 'hari_operasional',
        'harga_tiket', 'keterangan_harga',
        'foto', 'rating', 'no_telepon',
        'status', 'submitter_user_id', 'catatan_admin', 'reviewed_at',
    ];
    protected $returnType = 'array';

    // Validation
    protected $validationRules = [
        'nama_tempat' => 'required|min_length[3]|max_length[255]',
    ];

    protected $validationMessages = [
        'nama_tempat' => [
            'required'   => 'Nama tempat wisata harus diisi',
            'min_length' => 'Nama tempat minimal 3 karakter',
        ],
    ];

    // ============================================================
    // HELPER — konversi boolean PostgreSQL ke PHP bool
    // PostgreSQL mengembalikan boolean sebagai string "t"/"f" via PDO
    // !empty("f") = TRUE karena "f" bukan string kosong — ini BUG!
    // ============================================================
    private function isTruthy($value): bool
    {
        if (is_bool($value)) return $value;
        if ($value === 't' || $value === 'true' || $value === '1' || $value === 1) return true;
        return false;
    }

    // ============================================================
    // HELPER — buat list fasilitas dari kolom boolean
    // ============================================================
    private function buildFasilitasList(array $row): array
    {
        $fasilitas = [];
        if ($this->isTruthy($row['toilet']      ?? null)) $fasilitas[] = 'Toilet';
        if ($this->isTruthy($row['parkir']       ?? null)) $fasilitas[] = 'Parkir';
        if ($this->isTruthy($row['area_bermain'] ?? null)) $fasilitas[] = 'Area Bermain Anak';
        if ($this->isTruthy($row['tempat_makan'] ?? null)) $fasilitas[] = 'Tempat Makan';
        if ($this->isTruthy($row['mushola']      ?? null)) $fasilitas[] = 'Mushola';
        if ($this->isTruthy($row['wifi']         ?? null)) $fasilitas[] = 'WiFi';
        return $fasilitas;
    }

    /**
     * Format satu row wisata untuk JSON response
     */
    private function formatRow(array $row, bool $includeFacilityFlags = false): array
    {
        $row['toilet'] = $this->isTruthy($row['toilet'] ?? null);
        $row['parkir'] = $this->isTruthy($row['parkir'] ?? null);
        $row['area_bermain'] = $this->isTruthy($row['area_bermain'] ?? null);
        $row['tempat_makan'] = $this->isTruthy($row['tempat_makan'] ?? null);
        $row['mushola'] = $this->isTruthy($row['mushola'] ?? null);
        $row['wifi'] = $this->isTruthy($row['wifi'] ?? null);
        $row['fasilitas'] = $this->buildFasilitasList($row);
        $row['foto'] = !empty($row['foto']) ? [$row['foto']] : [];

        if (!$includeFacilityFlags) {
            unset($row['toilet'], $row['parkir'], $row['area_bermain'],
                  $row['tempat_makan'], $row['mushola'], $row['wifi']);
        }

        return $row;
    }

    /**
     * Lengkapi row wisata dengan foto galeri dari tabel wisata_foto.
     */
    private function appendGalleryPhotos(array $rows): array
    {
        if (empty($rows) || !$this->tableExists('wisata_foto')) {
            return $rows;
        }

        $wisataIds = array_values(array_filter(array_map(
            static fn($row) => isset($row['id']) ? (int) $row['id'] : 0,
            $rows
        )));

        if (empty($wisataIds)) {
            return $rows;
        }

        try {
            $galleryRows = $this->db->table('wisata_foto')
                ->select('wisata_id, foto_url')
                ->whereIn('wisata_id', $wisataIds)
                ->orderBy('created_at', 'ASC')
                ->get()
                ->getResultArray();
        } catch (\Throwable $e) {
            log_message('warning', 'wisata_foto batch query failed: ' . $e->getMessage());
            return $rows;
        }

        $galleryByWisataId = [];
        foreach ($galleryRows as $galleryRow) {
            $wisataId = (int) ($galleryRow['wisata_id'] ?? 0);
            $fotoUrl = trim((string) ($galleryRow['foto_url'] ?? ''));

            if ($wisataId <= 0 || $fotoUrl === '') {
                continue;
            }

            $galleryByWisataId[$wisataId][] = $fotoUrl;
        }

        foreach ($rows as &$row) {
            $rowId = isset($row['id']) ? (int) $row['id'] : 0;
            $mainPhotos = isset($row['foto']) && is_array($row['foto']) ? $row['foto'] : [];
            $extraPhotos = $galleryByWisataId[$rowId] ?? [];
            $row['foto'] = array_values(array_unique(array_filter(array_merge($mainPhotos, $extraPhotos))));
        }
        unset($row);

        return $rows;
    }

    // ============================================================
    // QUERY METHODS
    // ============================================================

    /**
     * Ambil semua wisata (opsional filter kategori)
     * Jika tabel punya kolom status, filter approved. Jika tidak, ambil semua.
     */
    public function getAll(?string $kategori = null): array
    {
        $hasStatus = $this->columnExists('status');

        $builder = $this->db->table('wisata w')
            ->select('w.id, w.nama_tempat, w.deskripsi, w.alamat, w.kecamatan, w.kelurahan,
                      w.kategori, w.target_pengunjung,
                      w.toilet, w.parkir, w.area_bermain, w.tempat_makan, w.mushola, w.wifi,
                      w.jam_buka, w.jam_tutup, w.hari_operasional,
                      w.harga_tiket, w.keterangan_harga,
                      w.foto, w.rating, w.no_telepon, w.status,
                      ST_Y(w.geom) AS latitude, ST_X(w.geom) AS longitude,
                      ' . $this->cityLabelSelectSql() . ',
                      ' . $this->submissionSelectSql())
            ->orderBy('w.nama_tempat', 'ASC');

        $this->applyAdminMobileJoin($builder);

        if ($hasStatus) {
            $builder->where('w.status', 'approved');
        }

        if ($kategori) {
            $builder->where('w.kategori', $kategori);
        }

        $rows = $builder->get()->getResultArray();
        $rows = array_map(fn($row) => $this->formatRow($row), $rows);

        return $this->appendGalleryPhotos($rows);
    }

    /**
     * Ambil wisata pending (untuk admin)
     */
    public function getPending(): array
    {
        if (!$this->columnExists('status')) {
            return [];
        }

        $builder = $this->db->table('wisata w')
            ->select('w.id, w.nama_tempat, w.deskripsi, w.alamat, w.kecamatan, w.kelurahan,
                      w.kategori, w.target_pengunjung,
                      w.toilet, w.parkir, w.area_bermain, w.tempat_makan, w.mushola, w.wifi,
                      w.jam_buka, w.jam_tutup, w.hari_operasional,
                      w.harga_tiket, w.keterangan_harga,
                      w.foto, w.rating, w.no_telepon, w.status,
                      ST_Y(w.geom) AS latitude, ST_X(w.geom) AS longitude,
                      ' . $this->cityLabelSelectSql() . ',
                      ' . $this->submissionSelectSql())
            ->where('w.status', 'pending')
            ->orderBy('w.id', 'DESC');

        $this->applyAdminMobileJoin($builder);

        $rows = $builder->get()->getResultArray();
        $rows = array_map(fn($row) => $this->formatRow($row), $rows);

        return $this->appendGalleryPhotos($rows);
    }

    /**
     * Detail wisata by ID
     */
    public function getDetail(int $id): ?array
    {
        $builder = $this->db->table('wisata w')
            ->select('w.id, w.nama_tempat, w.deskripsi, w.alamat, w.kecamatan, w.kelurahan,
                      w.kategori, w.target_pengunjung,
                      w.toilet, w.parkir, w.area_bermain, w.tempat_makan, w.mushola, w.wifi,
                      w.jam_buka, w.jam_tutup, w.hari_operasional,
                      w.harga_tiket, w.keterangan_harga,
                      w.foto, w.rating, w.no_telepon, w.status,
                      ST_Y(w.geom) AS latitude, ST_X(w.geom) AS longitude,
                      ' . $this->cityLabelSelectSql() . ',
                      ' . $this->submissionSelectSql())
            ->where('w.id', $id);

        $this->applyAdminMobileJoin($builder);

        $row = $builder->get()->getRowArray();

        if (!$row) return null;

        $formatted = $this->formatRow($row, true);
        $formattedRows = $this->appendGalleryPhotos([$formatted]);

        return $formattedRows[0] ?? $formatted;
    }

    /**
     * Cari wisata terdekat dari koordinat user (PostGIS)
     */
    public function getNearby(float $lat, float $lng, int $limit = 5): array
    {
        $hasStatus = $this->columnExists('status');
        $statusClause = $hasStatus ? "AND status = 'approved'" : '';

        $sql = "SELECT
                    id, nama_tempat, deskripsi, alamat, kategori,
                    toilet, parkir, area_bermain, tempat_makan, mushola, wifi,
                    harga_tiket, no_telepon, foto, rating,
                    ST_Y(geom) AS latitude,
                    ST_X(geom) AS longitude,
                    ROUND(CAST(ST_DistanceSphere(geom, ST_SetSRID(ST_MakePoint(?, ?), 4326)) AS NUMERIC), 0) AS jarak_meter,
                    ROUND(CAST(ST_DistanceSphere(geom, ST_SetSRID(ST_MakePoint(?, ?), 4326)) / 1000.0 AS NUMERIC), 2) AS jarak_km
                FROM wisata
                WHERE geom IS NOT NULL {$statusClause}
                ORDER BY geom <-> ST_SetSRID(ST_MakePoint(?, ?), 4326)
                LIMIT ?";

        $result = $this->db->query($sql, [$lng, $lat, $lng, $lat, $lng, $lat, $limit]);
        $rows = $result->getResultArray();
        $rows = array_map(fn($row) => $this->formatRow($row), $rows);

        return $this->appendGalleryPhotos($rows);
    }

    /**
     * Insert wisata dengan koordinat PostGIS
     */
    public function createWithGeom(array $data, float $lat, float $lng): int|false
    {
        // Pastikan status = pending jika kolom ada
        if ($this->columnExists('status')) {
            $data['status'] = $data['status'] ?? 'pending';
        }

        $this->insert($data);
        $id = $this->getInsertID();

        if ($id) {
            $sql = "UPDATE wisata SET geom = ST_SetSRID(ST_MakePoint(?, ?), 4326) WHERE id = ?";
            $this->db->query($sql, [$lng, $lat, $id]);
        }

        return $id;
    }

    /**
     * Update wisata dengan koordinat PostGIS
     */
    public function updateWithGeom(int $id, array $data, ?float $lat = null, ?float $lng = null): bool
    {
        $this->update($id, $data);

        if ($lat !== null && $lng !== null) {
            $sql = "UPDATE wisata SET geom = ST_SetSRID(ST_MakePoint(?, ?), 4326) WHERE id = ?";
            $this->db->query($sql, [$lng, $lat, $id]);
        }

        return true;
    }

    /**
     * Ambil daftar kategori unik dari data yang ada
     */
    public function getDistinctKategori(): array
    {
        $result = $this->db->query(
            "SELECT DISTINCT kategori FROM wisata WHERE kategori IS NOT NULL AND kategori != '' ORDER BY kategori ASC"
        );

        return array_column($result->getResultArray(), 'kategori');
    }

    /**
     * Cek apakah kolom ada di tabel (untuk backward compatibility)
     */
    private function columnExists(string $column): bool
    {
        static $columns = null;
        if ($columns === null) {
            $result = $this->db->query(
                "SELECT column_name FROM information_schema.columns WHERE table_name = 'wisata' AND table_schema = 'public'"
            );
            $columns = array_column($result->getResultArray(), 'column_name');
        }
        return in_array($column, $columns);
    }

    private function tableExists(string $table): bool
    {
        static $tables = null;
        if ($tables === null) {
            $result = $this->db->query(
                "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
            );
            $tables = array_column($result->getResultArray(), 'table_name');
        }

        return in_array($table, $tables);
    }

    private function applyAdminMobileJoin($builder): void
    {
        if ($this->columnExists('submitter_user_id') && $this->tableExists('admin_mobile')) {
            $builder->join('admin_mobile am', 'am.id = w.submitter_user_id', 'left');
        }
    }

    private function submissionSelectSql(): string
    {
        $segments = [
            $this->columnExists('submitter_user_id')
                ? 'w.submitter_user_id'
                : 'NULL AS submitter_user_id',
            $this->columnExists('catatan_admin')
                ? 'w.catatan_admin'
                : 'NULL AS catatan_admin',
        ];

        if ($this->columnExists('submitter_user_id') && $this->tableExists('admin_mobile')) {
            $segments[] = 'am.username AS submitter_nama';
            $segments[] = 'am.no_pegawai AS submitter_no_pegawai';
            $segments[] = 'am.foto_profil AS submitter_foto_profil';
        } else {
            $segments[] = 'NULL AS submitter_nama';
            $segments[] = 'NULL AS submitter_no_pegawai';
            $segments[] = 'NULL AS submitter_foto_profil';
        }

        return implode(",\n                      ", $segments);
    }

    private function cityLabelSelectSql(): string
    {
        $hasMedanBoundary = $this->tableExists('gis_boundaries_medan');
        $hasDeliBoundary = $this->tableExists('gis_boundaries_deli_serdang');

        if (!$hasMedanBoundary && !$hasDeliBoundary) {
            return 'NULL AS kota_kabupaten';
        }

        $cases = [];

        if ($hasMedanBoundary) {
            $cases[] = "WHEN w.geom IS NOT NULL AND EXISTS (
                SELECT 1
                FROM gis_boundaries_medan gbm
                WHERE ST_Intersects(gbm.geom, w.geom)
            ) THEN 'Kota Medan'";
        }

        if ($hasDeliBoundary) {
            $cases[] = "WHEN w.geom IS NOT NULL AND EXISTS (
                SELECT 1
                FROM gis_boundaries_deli_serdang gbd
                WHERE ST_Intersects(gbd.geom, w.geom)
            ) THEN 'Kabupaten Deli Serdang'";
        }

        return "CASE\n                " . implode("\n                ", $cases) . "\n                ELSE NULL\n            END AS kota_kabupaten";
    }
}
