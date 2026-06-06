<?php

namespace App\Models;

use CodeIgniter\Model;

class WisataFasilitasModel extends Model
{
    protected $table         = 'wisata_fasilitas';
    protected $primaryKey    = 'id';
    protected $allowedFields = ['wisata_id', 'fasilitas_id'];
    protected $returnType    = 'array';

    /**
     * Ambil daftar fasilitas untuk wisata tertentu
     */
    public function getFasilitasByWisata(int $wisataId): array
    {
        return $this->select('fasilitas.id, fasilitas.nama_fasilitas')
            ->join('fasilitas', 'fasilitas.id = wisata_fasilitas.fasilitas_id')
            ->where('wisata_fasilitas.wisata_id', $wisataId)
            ->orderBy('fasilitas.nama_fasilitas', 'ASC')
            ->findAll();
    }

    /**
     * Simpan fasilitas untuk wisata (batch)
     */
    public function syncFasilitas(int $wisataId, array $fasilitasIds): void
    {
        // Hapus semua relasi lama
        $this->where('wisata_id', $wisataId)->delete();

        // Insert relasi baru
        $data = [];
        foreach ($fasilitasIds as $fasId) {
            $data[] = [
                'wisata_id'    => $wisataId,
                'fasilitas_id' => (int) $fasId,
            ];
        }
        if (!empty($data)) {
            $this->insertBatch($data);
        }
    }
}
