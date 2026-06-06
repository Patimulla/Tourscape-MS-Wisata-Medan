<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use App\Libraries\SupabaseStorage;
use CodeIgniter\HTTP\ResponseInterface;

/**
 * UploadController — Upload foto ke Supabase Storage
 */
class UploadController extends BaseController
{
    /**
     * POST /api/upload
     * Upload file foto ke Supabase Storage
     *
     * Request: multipart/form-data dengan field "foto"
     * Response: { success, url, message }
     */
    public function foto(): ResponseInterface
    {
        $file = $this->request->getFile('foto');

        if (!$file || !$file->isValid()) {
            return $this->response->setStatusCode(400)->setJSON([
                'status'  => false,
                'message' => 'File foto tidak valid atau tidak ditemukan. Pastikan field name = "foto"',
            ]);
        }

        // Validasi tipe file
        $allowedMimes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
        if (!in_array($file->getMimeType(), $allowedMimes)) {
            return $this->response->setStatusCode(400)->setJSON([
                'status'  => false,
                'message' => 'Tipe file tidak diizinkan. Gunakan JPG, PNG, WEBP, atau GIF.',
            ]);
        }

        // Validasi ukuran (max 5MB)
        if ($file->getSizeByUnit('mb') > 5) {
            return $this->response->setStatusCode(400)->setJSON([
                'status'  => false,
                'message' => 'Ukuran file maksimal 5MB',
            ]);
        }

        // Upload ke Supabase
        $supabase = new SupabaseStorage();
        $fileName = $supabase->generateFileName($file->getClientName(), 'wisata');

        $result = $supabase->upload(
            $file->getTempName(),
            $fileName,
            $file->getMimeType()
        );

        if ($result['success']) {
            return $this->response->setJSON([
                'status'  => true,
                'message' => 'Foto berhasil diupload',
                'data'    => [
                    'url'       => $result['url'],
                    'file_name' => $fileName,
                ],
            ]);
        }

        return $this->response->setStatusCode(500)->setJSON([
            'status'  => false,
            'message' => $result['message'],
        ]);
    }
}
