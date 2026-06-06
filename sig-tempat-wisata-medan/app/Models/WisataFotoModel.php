<?php

namespace App\Models;

use CodeIgniter\Model;

class WisataFotoModel extends Model
{
    protected $table         = 'wisata_foto';
    protected $primaryKey    = 'id';
    protected $allowedFields = ['wisata_id', 'foto_url'];
    protected $returnType    = 'array';

    // Timestamps
    protected $useTimestamps = true;
    protected $createdField  = 'created_at';
    protected $updatedField  = '';
    protected $dateFormat    = 'datetime';

    /**
     * Ambil semua foto untuk wisata tertentu
     */
    public function getFotoByWisata(int $wisataId): array
    {
        return $this->where('wisata_id', $wisataId)
            ->orderBy('created_at', 'ASC')
            ->findAll();
    }

    /**
     * Simpan beberapa foto sekaligus
     */
    public function addFotos(int $wisataId, array $fotoUrls): void
    {
        $data = [];
        foreach ($fotoUrls as $url) {
            $data[] = [
                'wisata_id' => $wisataId,
                'foto_url'  => $url,
            ];
        }
        if (!empty($data)) {
            $this->insertBatch($data);
        }
    }
}
