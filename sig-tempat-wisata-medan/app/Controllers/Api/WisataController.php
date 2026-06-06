<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use App\Models\ReviewModel;
use App\Models\WisataFotoModel;
use App\Models\WisataModel;
use CodeIgniter\HTTP\ResponseInterface;

class WisataController extends BaseController
{
    protected WisataModel $wisataModel;
    protected ReviewModel $reviewModel;
    protected WisataFotoModel $wisataFotoModel;

    public function __construct()
    {
        $this->wisataModel = new WisataModel();
        $this->reviewModel = new ReviewModel();
        $this->wisataFotoModel = new WisataFotoModel();
    }

    /**
     * GET /api/wisata
     * Daftar semua wisata
     * Query params: ?kategori=Taman
     */
    public function index(): ResponseInterface
    {
        $kategori = $this->request->getGet('kategori');

        $data = $this->wisataModel->getAll($kategori ?: null);

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Data wisata berhasil diambil',
            'data'    => $data,
        ]);
    }

    /**
     * GET /api/wisata/nearby?lat=3.5952&lng=98.6722&limit=5
     * Wisata terdekat dari koordinat user
     */
    public function nearby(): ResponseInterface
    {
        $lat   = $this->request->getGet('lat');
        $lng   = $this->request->getGet('lng');
        $limit = $this->request->getGet('limit') ?? 5;

        if (!$lat || !$lng) {
            return $this->response->setStatusCode(400)->setJSON([
                'status'  => false,
                'message' => 'Parameter lat dan lng wajib diisi',
            ]);
        }

        $data = $this->wisataModel->getNearby(
            (float) $lat,
            (float) $lng,
            (int) $limit
        );

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Data wisata terdekat berhasil diambil',
            'data'    => $data,
        ]);
    }

    /**
     * GET /api/wisata/{id}
     * Detail wisata
     */
    public function show(int $id): ResponseInterface
    {
        $wisata = $this->wisataModel->getDetail($id);

        if (!$wisata) {
            return $this->response->setStatusCode(404)->setJSON([
                'status'  => false,
                'message' => 'Data wisata tidak ditemukan',
            ]);
        }

        if (array_key_exists('status', $wisata) && $wisata['status'] !== null && $wisata['status'] !== 'approved') {
            if (session()->get('is_admin') !== true) {
                return $this->response->setStatusCode(404)->setJSON([
                    'status'  => false,
                    'message' => 'Data wisata tidak tersedia untuk publik',
                ]);
            }
        }

        $rating = $this->reviewModel->getAverageRating($id);

        // Fetch extra photos — wrapped in try-catch in case wisata_foto
        // table hasn't been migrated yet on the remote DB.
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
            // wisata_foto table may not exist yet — ignore and continue
            log_message('warning', 'wisata_foto query failed: ' . $e->getMessage());
        }

        $foto = array_values(array_unique(array_filter($foto)));

        $storedRating = isset($wisata['rating']) ? (float) $wisata['rating'] : 0.0;
        $wisata['rating_avg'] = ($rating['rating_avg'] ?? 0) > 0
            ? $rating['rating_avg']
            : $storedRating;
        $wisata['total_review'] = $rating['total_review'] ?? 0;
        $wisata['foto'] = $foto;

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Detail wisata berhasil diambil',
            'data'    => $wisata,
        ]);
    }

    /**
     * POST /api/wisata
     * Input wisata baru (status = pending)
     *
     * Mendukung 2 format:
     * 1. JSON body (foto berupa URL string)
     * 2. multipart/form-data (foto berupa file upload → Supabase)
     */
    public function create(): ResponseInterface
    {
        // Deteksi apakah request multipart (ada file) atau JSON
        $file = $this->request->getFile('foto');
        $isMultipart = $file && $file->isValid();

        // Ambil data dari JSON atau form-data
        if ($isMultipart) {
            $data = $this->request->getPost();
        } else {
            $data = $this->request->getJSON(true) ?? $this->request->getPost();
        }

        // Validasi
        $rules = [
            'nama_tempat' => 'required|min_length[3]',
            'latitude'    => 'required|decimal',
            'longitude'   => 'required|decimal',
        ];

        if (!$this->validateData($data, $rules)) {
            return $this->response->setStatusCode(400)->setJSON([
                'status'  => false,
                'message' => 'Validasi gagal',
                'errors'  => $this->validator->getErrors(),
            ]);
        }

        // Upload foto ke Supabase jika ada file
        $fotoUrl = $data['foto'] ?? null;
        if ($isMultipart) {
            // Validasi file
            $allowedMimes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/octet-stream'];
            $mimeType = $file->getMimeType();
            $clientMime = $file->getClientMimeType();
            
            if (!in_array($mimeType, $allowedMimes) && !in_array($clientMime, $allowedMimes)) {
                return $this->response->setStatusCode(400)->setJSON([
                    'status'  => false,
                    'message' => 'Tipe file tidak diizinkan (' . $mimeType . ' / ' . $clientMime . '). Gunakan JPG, PNG, WEBP, atau GIF.',
                ]);
            }

            if ($file->getSizeByUnit('mb') > 5) {
                return $this->response->setStatusCode(400)->setJSON([
                    'status'  => false,
                    'message' => 'Ukuran file maksimal 5MB',
                ]);
            }

            $supabase = new \App\Libraries\SupabaseStorage();
            $fileName = $supabase->generateFileName($file->getClientName(), 'wisata');
            $uploadResult = $supabase->upload(
                $file->getTempName(),
                $fileName,
                $file->getMimeType()
            );

            if (!$uploadResult['success']) {
                return $this->response->setStatusCode(500)->setJSON([
                    'status'  => false,
                    'message' => 'Gagal upload foto: ' . $uploadResult['message'],
                ]);
            }

            $fotoUrl = $uploadResult['url'];
        }

        $wisataData = [
            'nama_tempat'       => $data['nama_tempat'],
            'deskripsi'         => $data['deskripsi'] ?? null,
            'alamat'            => $data['alamat'] ?? null,
            'kecamatan'         => $data['kecamatan'] ?? null,
            'kelurahan'         => $data['kelurahan'] ?? null,
            'kategori'          => $data['kategori'] ?? null,
            'target_pengunjung' => $data['target_pengunjung'] ?? null,
            'toilet'            => !empty($data['toilet']),
            'parkir'            => !empty($data['parkir']),
            'area_bermain'      => !empty($data['area_bermain']),
            'tempat_makan'      => !empty($data['tempat_makan']),
            'mushola'           => !empty($data['mushola']),
            'wifi'              => !empty($data['wifi']),
            'jam_buka'          => $data['jam_buka'] ?? null,
            'jam_tutup'         => $data['jam_tutup'] ?? null,
            'hari_operasional'  => $data['hari_operasional'] ?? null,
            'harga_tiket'       => $data['harga_tiket'] ?? 0,
            'keterangan_harga'  => $data['keterangan_harga'] ?? null,
            'no_telepon'        => $data['no_telepon'] ?? null,
            'foto'              => $fotoUrl,
            'rating'            => $data['rating'] ?? null,
            'status'            => 'pending',
        ];

        $lat = (float) $data['latitude'];
        $lng = (float) $data['longitude'];

        $id = $this->wisataModel->createWithGeom($wisataData, $lat, $lng);

        if (!$id) {
            return $this->response->setStatusCode(500)->setJSON([
                'status'  => false,
                'message' => 'Gagal menyimpan data wisata',
            ]);
        }

        return $this->response->setStatusCode(201)->setJSON([
            'status'  => true,
            'message' => 'Data wisata berhasil disimpan (status: pending)',
            'data'    => [
                'id'   => $id,
                'foto' => $fotoUrl,
            ],
        ]);
    }

    /**
     * PUT /api/wisata/{id}
     */
    public function update(int $id): ResponseInterface
    {
        $existing = $this->wisataModel->find($id);
        if (!$existing) {
            return $this->response->setStatusCode(404)->setJSON([
                'status'  => false,
                'message' => 'Data wisata tidak ditemukan',
            ]);
        }

        if (($existing['status'] ?? null) !== 'approved') {
            return $this->response->setStatusCode(403)->setJSON([
                'status'  => false,
                'message' => 'Data yang belum approved tidak dapat diedit dari panel web. Minta pengaju melakukan revisi dari aplikasi mobile.',
            ]);
        }

        $json = $this->request->getJSON(true);

        $wisataData = [];
        $fields = [
            'nama_tempat', 'deskripsi', 'alamat', 'kecamatan', 'kelurahan',
            'kategori', 'target_pengunjung',
            'toilet', 'parkir', 'area_bermain', 'tempat_makan', 'mushola', 'wifi',
            'jam_buka', 'jam_tutup', 'hari_operasional',
            'harga_tiket', 'keterangan_harga', 'no_telepon', 'rating',
        ];

        foreach ($fields as $field) {
            if (isset($json[$field])) {
                $wisataData[$field] = $json[$field];
            }
        }

        // Handle multiple photos
        if (isset($json['foto'])) {
            $fotoData = $json['foto'];
            $fotoUrls = [];
            if (!is_array($fotoData)) {
                $fotoUrls = array_filter(array_map('trim', explode(',', $fotoData)));
            } else {
                $fotoUrls = array_filter($fotoData);
            }
            
            // Delete old gallery
            $this->wisataFotoModel->where('wisata_id', $id)->delete();

            if (!empty($fotoUrls)) {
                // First photo goes to main table
                $wisataData['foto'] = array_shift($fotoUrls);
                
                // Rest goes to gallery
                if (!empty($fotoUrls)) {
                    $this->wisataFotoModel->addFotos($id, $fotoUrls);
                }
            } else {
                $wisataData['foto'] = '';
            }
        }

        $lat = isset($json['latitude']) ? (float) $json['latitude'] : null;
        $lng = isset($json['longitude']) ? (float) $json['longitude'] : null;

        $this->wisataModel->updateWithGeom($id, $wisataData, $lat, $lng);

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Data wisata berhasil diperbarui',
        ]);
    }

    /**
     * DELETE /api/wisata/{id}
     */
    public function delete(int $id): ResponseInterface
    {
        $existing = $this->wisataModel->find($id);
        if (!$existing) {
            return $this->response->setStatusCode(404)->setJSON([
                'status'  => false,
                'message' => 'Data wisata tidak ditemukan',
            ]);
        }

        $this->wisataModel->delete($id);

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Data wisata berhasil dihapus',
        ]);
    }
}
