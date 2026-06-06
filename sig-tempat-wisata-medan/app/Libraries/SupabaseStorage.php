<?php

namespace App\Libraries;

/**
 * SupabaseStorage — Upload file ke Supabase Storage
 *
 * Menggunakan Supabase Storage REST API:
 * POST /storage/v1/object/{bucket}/{path}
 *
 * Public URL:
 * GET /storage/v1/object/public/{bucket}/{path}
 */
class SupabaseStorage
{
    private string $url;
    private string $key;
    private string $bucket;

    public function __construct()
    {
        $this->url    = rtrim($this->envValue('SUPABASE_URL', 'supabase.url'), '/');
        $this->key    = $this->envValue('SUPABASE_KEY', 'supabase.key');
        $this->bucket = $this->envValue('SUPABASE_BUCKET', 'supabase.bucket');
    }

    private function envValue(string $primary, string $legacy): string
    {
        $fallback = match ($primary) {
            'SUPABASE_URL'    => 'https://ekslfvczghsmiqkothdm.supabase.co',
            'SUPABASE_KEY'    => 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVrc2xmdmN6Z2hzbWlxa290aGRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODc3ODYsImV4cCI6MjA5MDU2Mzc4Nn0.uFwuatl1DX8Xlhdb70fhgc7AJrD-OVb5xczOUQ4503Y',
            'SUPABASE_BUCKET' => 'gis wisata',
            default           => '',
        };

        $value = app_env($primary);

        if ($value !== null && $value !== false && $value !== '') {
            return (string) $value;
        }

        return (string) app_env($legacy, $fallback);
    }

    /**
     * Upload file ke Supabase Storage
     *
     * @param string $filePath  Path file lokal (tmp upload)
     * @param string $fileName  Nama file tujuan di bucket (bisa include folder, e.g. "wisata/foto.jpg")
     * @param string $mimeType  MIME type file (e.g. "image/jpeg")
     * @return array ['success' => bool, 'url' => string|null, 'message' => string]
     */
    public function upload(string $filePath, string $fileName, string $mimeType = 'image/jpeg'): array
    {
        if (empty($this->url) || empty($this->key) || empty($this->bucket)) {
            return [
                'success' => false,
                'url'     => null,
                'message' => 'Supabase config belum lengkap (cek .env)',
            ];
        }

        if (!file_exists($filePath)) {
            return [
                'success' => false,
                'url'     => null,
                'message' => 'File tidak ditemukan: ' . $filePath,
            ];
        }

        // Encode bucket name (karena ada spasi)
        $bucketEncoded = rawurlencode($this->bucket);

        // API endpoint
        $endpoint = "{$this->url}/storage/v1/object/{$bucketEncoded}/{$fileName}";

        // Read file content
        $fileData = file_get_contents($filePath);

        // cURL request
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $endpoint,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $fileData,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 30,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $this->key,
                'Content-Type: ' . $mimeType,
                'x-upsert: true',  // Overwrite jika sudah ada
            ],
            CURLOPT_SSL_VERIFYPEER => false, // Fix untuk lokal Windows
        ]);

        $response   = curl_exec($ch);
        $httpCode   = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError  = curl_error($ch);
        curl_close($ch);

        if ($curlError) {
            return [
                'success' => false,
                'url'     => null,
                'message' => 'cURL error: ' . $curlError,
            ];
        }

        $responseData = json_decode($response, true);

        if ($httpCode === 200 || $httpCode === 201) {
            // Build public URL
            $publicUrl = "{$this->url}/storage/v1/object/public/{$bucketEncoded}/{$fileName}";

            return [
                'success' => true,
                'url'     => $publicUrl,
                'message' => 'Upload berhasil',
            ];
        }

        return [
            'success' => false,
            'url'     => null,
            'message' => 'Upload gagal: ' . ($responseData['message'] ?? $responseData['error'] ?? "HTTP {$httpCode}"),
        ];
    }

    /**
     * Generate nama file unik untuk upload
     *
     * @param string $originalName  Nama file asli (e.g. "foto.jpg")
     * @param string $folder        Folder di bucket (e.g. "wisata")
     * @return string               Path di bucket (e.g. "wisata/1715087000_a1b2c3.jpg")
     */
    public function generateFileName(string $originalName, string $folder = 'wisata'): string
    {
        $ext = pathinfo($originalName, PATHINFO_EXTENSION);
        $ext = strtolower($ext) ?: 'jpg';
        $uniqueName = time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;

        return $folder . '/' . $uniqueName;
    }

    /**
     * Hapus file dari Supabase Storage
     *
     * @param string $fileName  Path file di bucket (e.g. "wisata/1715087000_abc.jpg")
     * @return bool
     */
    public function delete(string $fileName): bool
    {
        $bucketEncoded = rawurlencode($this->bucket);
        $endpoint = "{$this->url}/storage/v1/object/{$bucketEncoded}/{$fileName}";

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $endpoint,
            CURLOPT_CUSTOMREQUEST  => 'DELETE',
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_HTTPHEADER     => [
                'Authorization: Bearer ' . $this->key,
            ],
            CURLOPT_SSL_VERIFYPEER => false,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return $httpCode === 200;
    }

    /**
     * Dapatkan public URL dari file yang sudah diupload
     *
     * @param string $fileName  Path file di bucket
     * @return string
     */
    public function getPublicUrl(string $fileName): string
    {
        $bucketEncoded = rawurlencode($this->bucket);
        return "{$this->url}/storage/v1/object/public/{$bucketEncoded}/{$fileName}";
    }
}
