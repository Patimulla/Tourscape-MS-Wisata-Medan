<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use App\Models\KecamatanModel;
use App\Services\GeoJsonCacheService;
use App\Services\KecamatanRoadService;
use CodeIgniter\HTTP\ResponseInterface;

class KecamatanController extends BaseController
{
    public function index(): ResponseInterface
    {
        $model = new KecamatanModel();

        $wilayah = $this->request->getGet('wilayah');
        if (!in_array($wilayah, [null, '', 'medan', 'deli_serdang'], true)) {
            return $this->response
                ->setStatusCode(422)
                ->setJSON([
                    'status' => false,
                    'message' => 'Parameter wilayah tidak valid.',
                ]);
        }

        $summaryList = $model->getSummaryList();
        if ($wilayah === 'medan' || $wilayah === 'deli_serdang') {
            $summaryList = array_values(array_filter(
                $summaryList,
                static fn(array $item): bool => ($item['wilayah'] ?? null) === $wilayah
            ));
        }

        return $this->response->setJSON([
            'status' => true,
            'data' => $summaryList,
        ]);
    }

    public function geojson(): ResponseInterface
    {
        $wilayah = $this->request->getGet('wilayah');
        $zoom = $this->request->getGet('zoom');
        if (!in_array($wilayah, [null, '', 'medan', 'deli_serdang'], true)) {
            return $this->response
                ->setStatusCode(422)
                ->setJSON([
                    'status' => false,
                    'message' => 'Parameter wilayah tidak valid.',
                ]);
        }

        $selectedWilayah = ($wilayah === '' || $wilayah === null) ? null : $wilayah;
        $model = new KecamatanModel();
        $zoomLevel = is_numeric($zoom) ? (int) round((float) $zoom) : 12;
        $zoomBucket = $model->normalizeZoomBucket($zoomLevel);
        $scopeKey = $selectedWilayah ?? 'both';
        $cache = new GeoJsonCacheService();

        return $this->response
            ->setHeader('Cache-Control', 'public, max-age=600, stale-while-revalidate=3600')
            ->setJSON(
                $cache->remember(
                    sprintf('kecamatan_collection:%s:%d', $scopeKey, $zoomBucket),
                    fn(): array => $model->getFeatureCollectionByWilayah($selectedWilayah, $zoomBucket),
                    [
                        'cache_type' => 'kecamatan_collection',
                        'scope' => $scopeKey,
                        'zoom_bucket' => $zoomBucket,
                    ],
                    720
                )
            )
            ->setContentType('application/geo+json');
    }

    public function show(int $id): ResponseInterface
    {
        $zoom = $this->request->getGet('zoom');
        $model = new KecamatanModel();
        $zoomLevel = is_numeric($zoom) ? (int) round((float) $zoom) : 15;
        $zoomBucket = $model->normalizeZoomBucket($zoomLevel);
        $cache = new GeoJsonCacheService();

        $featureCollection = $cache->remember(
            sprintf('kecamatan_polygon:%d:%d', $id, $zoomBucket),
            fn() => $model->getFeatureCollectionById($id, $zoomBucket),
            [
                'cache_type' => 'kecamatan_polygon',
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
                    'message' => 'Kecamatan tidak ditemukan.',
                ]);
        }

        return $this->response
            ->setHeader('Cache-Control', 'public, max-age=600, stale-while-revalidate=3600')
            ->setJSON($featureCollection)
            ->setContentType('application/geo+json');
    }

    public function roads(int $id): ResponseInterface
    {
        $zoom = $this->request->getGet('zoom');
        $zoomLevel = is_numeric($zoom) ? (int) round((float) $zoom) : 15;

        $featureCollection = (new KecamatanRoadService())->getRoadFeatureCollection($id, $zoomLevel);
        if ($featureCollection === null) {
            return $this->response
                ->setStatusCode(404)
                ->setJSON([
                    'status' => false,
                    'message' => 'Kecamatan tidak ditemukan.',
                ]);
        }

        return $this->response
            ->setJSON($featureCollection)
            ->setContentType('application/geo+json');
    }
}
