<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use App\Models\KategoriModel;
use CodeIgniter\HTTP\ResponseInterface;

class KategoriController extends BaseController
{
    public function index(): ResponseInterface
    {
        $kategoriModel = new KategoriModel();
        $data = $kategoriModel->orderBy('nama_kategori', 'ASC')->findAll();

        return $this->response->setJSON([
            'status'  => true,
            'message' => 'Data kategori berhasil diambil',
            'data'    => $data,
        ]);
    }
}
