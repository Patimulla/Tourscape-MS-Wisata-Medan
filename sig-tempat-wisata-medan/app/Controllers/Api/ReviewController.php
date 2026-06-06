<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use App\Models\ReviewModel;
use CodeIgniter\HTTP\ResponseInterface;

class ReviewController extends BaseController
{
    protected ReviewModel $reviewModel;

    public function __construct()
    {
        $this->reviewModel = new ReviewModel();
    }

    /**
     * GET /api/wisata/{id}/review
     * Daftar review untuk wisata tertentu
     */
    public function index(int $wisataId): ResponseInterface
    {
        $reviews = $this->reviewModel->getReviewByWisata($wisataId);
        $rating  = $this->reviewModel->getAverageRating($wisataId);

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Data review berhasil diambil',
            'data'    => [
                'rating_avg'   => $rating['rating_avg'],
                'total_review' => $rating['total_review'],
                'reviews'      => $reviews,
            ],
        ]);
    }

    /**
     * POST /api/wisata/{id}/review
     * Tambah review baru
     *
     * Body JSON:
     * {
     *   "nama_reviewer": "Ahmad",
     *   "rating": 5,
     *   "ulasan": "Tempat yang bagus!"
     * }
     */
    public function create(int $wisataId): ResponseInterface
    {
        $json = $this->request->getJSON(true);
        $json['wisata_id'] = $wisataId;

        $rules = [
            'nama_reviewer' => 'required|min_length[2]',
            'rating'        => 'required|integer|greater_than[0]|less_than[6]',
        ];

        if (!$this->validateData($json, $rules)) {
            return $this->response->setStatusCode(400)->setJSON([
                'status'  => false,
                'message' => 'Validasi gagal',
                'errors'  => $this->validator->getErrors(),
            ]);
        }

        $this->reviewModel->insert($json);

        return $this->response->setStatusCode(201)->setJSON([
            'status'  => true,
            'message' => 'Review berhasil ditambahkan',
        ]);
    }
}
