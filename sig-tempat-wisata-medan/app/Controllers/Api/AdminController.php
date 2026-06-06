<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use App\Models\WisataFotoModel;
use App\Models\WisataModel;
use CodeIgniter\HTTP\ResponseInterface;

class AdminController extends BaseController
{
    protected WisataModel $wisataModel;
    protected WisataFotoModel $wisataFotoModel;

    public function __construct()
    {
        $this->wisataModel    = new WisataModel();
        $this->wisataFotoModel = new WisataFotoModel();
    }

    private function tableExists(string $table): bool
    {
        $result = $this->wisataModel->db->query(
            "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = ? LIMIT 1",
            [$table]
        );

        return !empty($result->getResultArray());
    }

    /**
     * GET /api/admin/wisata/pending
     */
    public function pending(): ResponseInterface
    {
        $data = $this->wisataModel->getPending();

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Data wisata pending berhasil diambil',
            'data'    => $data,
        ]);
    }

    /**
     * GET /api/admin/mobile-users
     * Daftar admin mobile untuk panel filter dan info pengaju
     */
    public function mobileUsers(): ResponseInterface
    {
        if (!$this->tableExists('admin_mobile')) {
            return $this->response->setJSON([
                'status'  => true,
                'message' => 'Tabel admin_mobile belum tersedia',
                'data'    => [],
            ]);
        }

        $hasSubmitterColumn = !empty($this->wisataModel->db->query(
            "SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'wisata' AND column_name = 'submitter_user_id' LIMIT 1"
        )->getResultArray());

        $countSelect = $hasSubmitterColumn
            ? <<<'SQL'
                COALESCE(SUM(CASE WHEN w.status = 'approved' THEN 1 ELSE 0 END), 0) AS total_approved,
                COALESCE(SUM(CASE WHEN w.status = 'pending' THEN 1 ELSE 0 END), 0) AS total_pending,
                COALESCE(SUM(CASE WHEN w.status = 'rejected' THEN 1 ELSE 0 END), 0) AS total_rejected,
                COALESCE(COUNT(w.id), 0) AS total_pengajuan
            SQL
            : <<<'SQL'
                0 AS total_approved,
                0 AS total_pending,
                0 AS total_rejected,
                0 AS total_pengajuan
            SQL;

        $sql = "
            SELECT
                am.id,
                am.username,
                am.no_pegawai,
                am.foto_profil,
                {$countSelect}
            FROM admin_mobile am
            " . ($hasSubmitterColumn ? "LEFT JOIN wisata w ON w.submitter_user_id = am.id" : '') . "
            GROUP BY am.id, am.username, am.no_pegawai, am.foto_profil
            ORDER BY am.username ASC
        ";

        $data = $this->wisataModel->db->query($sql)->getResultArray();

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Daftar admin mobile berhasil diambil',
            'data'    => $data,
        ]);
    }

    /**
     * GET /api/admin/wisata/{id}
     * Detail ANY wisata (pending/approved/rejected) — tanpa filter status
     */
    public function detail(int $id): ResponseInterface
    {
        $wisata = $this->wisataModel->getDetail($id);

        if (!$wisata) {
            return $this->response->setStatusCode(404)->setJSON([
                'status'  => false,
                'message' => 'Data wisata tidak ditemukan',
            ]);
        }

        // Merge gallery photos from wisata_foto
        $foto = $wisata['foto'] ?? [];
        if (!is_array($foto)) {
            $foto = [];
        }

        try {
            $extraFotos = $this->wisataFotoModel->getFotoByWisata($id);
            foreach ($extraFotos as $item) {
                $url = $item['foto_url'] ?? null;
                if ($url) {
                    $foto[] = $url;
                }
            }
        } catch (\Throwable $e) {
            log_message('warning', 'wisata_foto query failed (admin detail): ' . $e->getMessage());
        }

        $wisata['foto'] = array_values(array_unique(array_filter($foto)));

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Detail wisata berhasil diambil',
            'data'    => $wisata,
        ]);
    }

    /**
     * PUT /api/admin/wisata/{id}/approve
     */
    public function approve(int $id): ResponseInterface
    {
        $wisata = $this->wisataModel->find($id);

        if (!$wisata) {
            return $this->response->setStatusCode(404)->setJSON([
                'status'  => false,
                'message' => 'Data wisata tidak ditemukan',
            ]);
        }

        $this->wisataModel->update($id, [
            'status' => 'approved',
            'catatan_admin' => null,
            'reviewed_at' => date('Y-m-d H:i:s'),
        ]);

        return $this->response->setJSON([
            'status'  => true,
            'message' => "Wisata '{$wisata['nama_tempat']}' berhasil di-approve",
        ]);
    }

    /**
     * PUT /api/admin/wisata/{id}/reject
     */
    public function reject(int $id): ResponseInterface
    {
        $wisata = $this->wisataModel->find($id);

        if (!$wisata) {
            return $this->response->setStatusCode(404)->setJSON([
                'status'  => false,
                'message' => 'Data wisata tidak ditemukan',
            ]);
        }

        $payload = $this->request->getJSON(true) ?? [];
        $catatanAdmin = trim((string) ($payload['catatan_admin'] ?? ''));

        if ($catatanAdmin === '') {
            return $this->response->setStatusCode(400)->setJSON([
                'status'  => false,
                'message' => 'Alasan penolakan atau permintaan perbaikan wajib diisi',
            ]);
        }

        $this->wisataModel->update($id, [
            'status' => 'rejected',
            'catatan_admin' => $catatanAdmin,
            'reviewed_at' => date('Y-m-d H:i:s'),
        ]);

        return $this->response->setJSON([
            'status'  => true,
            'message' => "Wisata '{$wisata['nama_tempat']}' telah ditolak",
            'data'    => [
                'catatan_admin' => $catatanAdmin,
            ],
        ]);
    }

    /**
     * POST /api/admin/migrate-foto-table
     * Membuat tabel wisata_foto jika belum ada
     */
    public function migrateFotoTable(): ResponseInterface
    {
        $db = \Config\Database::connect();

        $sql = <<<'SQL'
        CREATE TABLE IF NOT EXISTS wisata_foto (
            id BIGSERIAL PRIMARY KEY,
            wisata_id BIGINT NOT NULL,
            foto_url VARCHAR(500) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        SQL;

        $indexSql = 'CREATE INDEX IF NOT EXISTS idx_wisata_foto_wisata_id ON wisata_foto (wisata_id);';

        // FK hanya tambah kalau belum ada
        $fkSql = <<<'SQL'
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'fk_wisata_foto_wisata_id'
            ) THEN
                ALTER TABLE wisata_foto
                ADD CONSTRAINT fk_wisata_foto_wisata_id
                FOREIGN KEY (wisata_id) REFERENCES wisata(id)
                ON DELETE CASCADE ON UPDATE CASCADE;
            END IF;
        END
        $$;
        SQL;

        try {
            $db->query($sql);
            $db->query($indexSql);
            $db->query($fkSql);

            // Mobile hanya perlu baca langsung. Insert galeri dilakukan lewat RPC security definer.
            $db->query('REVOKE INSERT, UPDATE, DELETE ON wisata_foto FROM anon, authenticated;');
            $db->query('GRANT SELECT ON wisata_foto TO anon, authenticated;');
            try {
                $db->query('REVOKE ALL ON SEQUENCE wisata_foto_id_seq FROM anon, authenticated;');
            } catch (\Throwable $ignored) { /* sequence mungkin belum ada */ }

            return $this->response->setJSON([
                'status'  => true,
                'message' => 'Tabel wisata_foto berhasil dibuat dengan grant mobile yang lebih aman',
            ]);
        } catch (\Throwable $e) {
            return $this->response->setStatusCode(500)->setJSON([
                'status'  => false,
                'message' => 'Gagal: ' . $e->getMessage(),
            ]);
        }
    }
}
