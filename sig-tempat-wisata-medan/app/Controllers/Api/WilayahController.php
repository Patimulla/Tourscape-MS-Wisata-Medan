<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use App\Models\WilayahAdministrasiModel;
use App\Services\GeoJsonCacheService;
use App\Services\WilayahRoadService;
use CodeIgniter\HTTP\ResponseInterface;

class WilayahController extends BaseController
{
    public function index(): ResponseInterface
    {
        $model = new WilayahAdministrasiModel();
        $kategori = $this->extractKategoriList($this->request->getGet('kategori'));
        $parentId = $this->request->getGet('parent_id');
        $wilayah = $this->request->getGet('wilayah');
        $search = $this->request->getGet('search');
        $page = max(1, (int) ($this->request->getGet('page') ?? 1));
        $perPage = max(1, (int) ($this->request->getGet('per_page') ?? 100));

        if ($wilayah !== null && $wilayah !== '' && !in_array($wilayah, ['medan', 'deli_serdang'], true)) {
            return $this->validationError('Parameter wilayah tidak valid.');
        }

        if ($parentId !== null && $parentId !== '' && !ctype_digit((string) $parentId)) {
            return $this->validationError('Parameter parent_id tidak valid.');
        }

        $result = $model->getSummaryList(
            $kategori,
            $parentId === null || $parentId === '' ? null : (int) $parentId,
            $wilayah === '' ? null : $wilayah,
            is_string($search) ? $search : null,
            $page,
            $perPage
        );

        return $this->response->setJSON([
            'status' => true,
            'data' => $result['data'],
            'pagination' => $result['pagination'],
        ]);
    }

    public function children(int $parentId): ResponseInterface
    {
        $kategori = $this->extractKategoriList($this->request->getGet('kategori'));
        $data = (new WilayahAdministrasiModel())->getChildrenSummary($parentId, $kategori);

        return $this->response->setJSON([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function childrenGeoJson(int $parentId): ResponseInterface
    {
        $model = new WilayahAdministrasiModel();
        $kategori = $this->extractKategoriList($this->request->getGet('kategori'));
        $zoom = $this->request->getGet('zoom');
        $zoomLevel = is_numeric($zoom) ? (int) round((float) $zoom) : 13;
        $zoomBucket = $model->normalizeZoomBucket($zoomLevel);
        $kategoriKey = $kategori === [] ? 'all' : implode('-', $kategori);
        $cache = new GeoJsonCacheService();

        $featureCollection = $cache->remember(
            sprintf('wilayah_children_collection:%d:%s:%d', $parentId, $kategoriKey, $zoomBucket),
            fn(): array => $model->getFeatureCollectionByParent($parentId, $kategori, $zoomBucket),
            [
                'cache_type' => 'wilayah_children_collection',
                'entity_id' => $parentId,
                'scope' => $kategoriKey,
                'zoom_bucket' => $zoomBucket,
            ],
            720
        );

        return $this->respondGeoJson($featureCollection);
    }

    public function kecamatan(): ResponseInterface
    {
        $wilayahId = $this->request->getGet('wilayah_id');
        $wilayah = $this->request->getGet('wilayah');

        if ($wilayahId !== null && $wilayahId !== '' && !ctype_digit((string) $wilayahId)) {
            return $this->validationError('Parameter wilayah_id tidak valid.');
        }

        if ($wilayah !== null && $wilayah !== '' && !in_array($wilayah, ['medan', 'deli_serdang'], true)) {
            return $this->validationError('Parameter wilayah tidak valid.');
        }

        $data = (new WilayahAdministrasiModel())->getKecamatanSummary(
            $wilayahId === null || $wilayahId === '' ? null : (int) $wilayahId,
            $wilayah === '' ? null : $wilayah
        );

        return $this->response->setJSON([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function kelurahan(): ResponseInterface
    {
        $kecamatanId = $this->request->getGet('kecamatan_id');
        if (!ctype_digit((string) $kecamatanId)) {
            return $this->validationError('Parameter kecamatan_id wajib berupa angka.');
        }

        $data = (new WilayahAdministrasiModel())->getLeafSummary((int) $kecamatanId);

        return $this->response->setJSON([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function resolve(): ResponseInterface
    {
        $lat = $this->request->getGet('lat');
        $lng = $this->request->getGet('lng');

        if (!is_numeric($lat) || !is_numeric($lng)) {
            return $this->validationError('Parameter lat dan lng wajib berupa angka.');
        }

        $data = (new WilayahAdministrasiModel())->resolveHierarchyByPoint((float) $lat, (float) $lng);

        return $this->response->setJSON([
            'status' => true,
            'data' => $data,
        ]);
    }

    public function show(int $id): ResponseInterface
    {
        $zoom = $this->request->getGet('zoom');
        $model = new WilayahAdministrasiModel();
        $zoomLevel = is_numeric($zoom) ? (int) round((float) $zoom) : 15;
        $zoomBucket = $model->normalizeZoomBucket($zoomLevel);
        $cache = new GeoJsonCacheService();

        $featureCollection = $cache->remember(
            sprintf('wilayah_polygon:%d:%d', $id, $zoomBucket),
            fn() => $model->getFeatureCollectionById($id, $zoomBucket),
            [
                'cache_type' => 'wilayah_polygon',
                'entity_id' => $id,
                'zoom_bucket' => $zoomBucket,
            ],
            720
        );
        if ($featureCollection === null) {
            return $this->response
                ->setStatusCode(404)
                ->setJSON([
                    'status' => false,
                    'message' => 'Wilayah tidak ditemukan.',
                ]);
        }

        return $this->respondGeoJson($featureCollection);
    }

    public function roads(int $id): ResponseInterface
    {
        $zoom = $this->request->getGet('zoom');
        $compact = filter_var($this->request->getGet('compact'), FILTER_VALIDATE_BOOL);
        $zoomLevel = is_numeric($zoom) ? (int) round((float) $zoom) : 15;

        $featureCollection = (new WilayahRoadService())->getRoadFeatureCollection($id, $zoomLevel, $compact);
        if ($featureCollection === null) {
            return $this->response
                ->setStatusCode(404)
                ->setJSON([
                    'status' => false,
                    'message' => 'Wilayah tidak ditemukan.',
                ]);
        }

        return $this->respondGeoJson($featureCollection);
    }

    /**
     * @return list<string>
     */
    private function extractKategoriList(mixed $rawKategori): array
    {
        if (!is_string($rawKategori) || trim($rawKategori) === '') {
            return [];
        }

        $valid = ['kota', 'kabupaten', 'kecamatan', 'kelurahan', 'desa'];
        $items = array_values(array_filter(array_map(
            static fn(string $value): string => trim($value),
            explode(',', $rawKategori)
        )));

        return array_values(array_intersect($items, $valid));
    }

    private function validationError(string $message): ResponseInterface
    {
        return $this->response
            ->setStatusCode(422)
            ->setJSON([
                'status' => false,
                'message' => $message,
            ]);
    }

    private function respondGeoJson(array $featureCollection): ResponseInterface
    {
        return $this->response
            ->setHeader('Cache-Control', 'public, max-age=600, stale-while-revalidate=3600')
            ->setJSON($featureCollection)
            ->setContentType('application/geo+json');
    }
}
