<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use App\Models\FasilitasModel;
use CodeIgniter\HTTP\ResponseInterface;

class FasilitasController extends BaseController
{
    protected FasilitasModel $fasilitasModel;

    public function __construct()
    {
        $this->fasilitasModel = new FasilitasModel();
    }

    /**
     * GET /api/fasilitas
     * Ambil semua fasilitas (untuk checkbox di form)
     */
    public function index(): ResponseInterface
    {
        $data = $this->fasilitasModel->orderBy('nama_fasilitas', 'ASC')->findAll();

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Data fasilitas berhasil diambil',
            'data'    => $data,
        ]);
    }
}
