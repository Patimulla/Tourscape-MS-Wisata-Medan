<?php

namespace App\Models;

use CodeIgniter\Model;

class ReviewModel extends Model
{
    protected $table         = 'review';
    protected $primaryKey    = 'id';
    protected $allowedFields = ['wisata_id', 'nama_reviewer', 'rating', 'ulasan'];
    protected $returnType    = 'array';

    // Timestamps
    protected $useTimestamps = true;
    protected $createdField  = 'created_at';
    protected $updatedField  = '';
    protected $dateFormat    = 'datetime';

    // Validation
    protected $validationRules = [
        'wisata_id'     => 'required|integer',
        'nama_reviewer' => 'required|min_length[2]|max_length[150]',
        'rating'        => 'required|integer|greater_than[0]|less_than[6]',
    ];

    protected $validationMessages = [
        'nama_reviewer' => [
            'required'   => 'Nama reviewer harus diisi',
            'min_length' => 'Nama reviewer minimal 2 karakter',
        ],
        'rating' => [
            'required'     => 'Rating harus diisi',
            'greater_than' => 'Rating minimal 1',
            'less_than'    => 'Rating maksimal 5',
        ],
    ];

    /**
     * Ambil review untuk wisata tertentu
     */
    public function getReviewByWisata(int $wisataId): array
    {
        return $this->where('wisata_id', $wisataId)
            ->orderBy('created_at', 'DESC')
            ->findAll();
    }

    /**
     * Hitung rata-rata rating wisata
     */
    public function getAverageRating(int $wisataId): array
    {
        $result = $this->selectAvg('rating', 'rating_avg')
            ->selectCount('id', 'total_review')
            ->where('wisata_id', $wisataId)
            ->first();

        return [
            'rating_avg'   => $result['rating_avg'] ? round((float) $result['rating_avg'], 1) : 0,
            'total_review' => (int) $result['total_review'],
        ];
    }
}
