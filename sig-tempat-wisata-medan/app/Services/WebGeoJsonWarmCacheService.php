<?php

namespace App\Services;

use App\Models\KecamatanModel;
use App\Models\WilayahAdministrasiModel;

class WebGeoJsonWarmCacheService
{
    public function __construct(
        private readonly WilayahAdministrasiModel $wilayahModel = new WilayahAdministrasiModel(),
        private readonly KecamatanModel $kecamatanModel = new KecamatanModel(),
        private readonly WilayahRoadService $roadService = new WilayahRoadService(),
        private readonly GeoJsonCacheService $cacheService = new GeoJsonCacheService()
    ) {
    }

    /**
     * @param array{
     *   polygon_zoom_buckets?: list<int>,
     *   roads_zoom_bucket?: int,
     *   include_roads?: bool,
     *   include_leaf?: bool,
     *   target_wilayah_ids?: list<int>
     * } $options
     * @return array<string, mixed>
     */
    public function warm(array $options = []): array
    {
        $polygonZoomBuckets = $options['polygon_zoom_buckets'] ?? [11, 13, 15];
        $roadsZoomBucket = $options['roads_zoom_bucket'] ?? 13;
        $includeRoads = (bool) ($options['include_roads'] ?? false);
        $includeLeaf = (bool) ($options['include_leaf'] ?? false);
        $targetWilayahIds = $options['target_wilayah_ids'] ?? [];

        $summary = [
            'warmed_polygon_entries' => 0,
            'warmed_collection_entries' => 0,
            'warmed_road_entries' => 0,
            'targets' => [],
            'collections' => [],
            'errors' => [],
        ];

        $topLevels = $this->wilayahModel->getSummaryList(['kota', 'kabupaten'], null, null, null, 1, 20)['data'];
        $kecamatanList = $this->wilayahModel->getSummaryList(['kecamatan'], null, null, null, 1, 100)['data'];
        $leafList = $includeLeaf
            ? $this->wilayahModel->getSummaryList(['kelurahan', 'desa'], null, null, null, 1, 1000)['data']
            : [];

        $targets = $this->resolveTargets($targetWilayahIds, $topLevels, $kecamatanList, $leafList);

        foreach ($polygonZoomBuckets as $zoomBucket) {
            $this->warmKecamatanCollectionCache(null, (int) $zoomBucket);
            $summary['warmed_collection_entries']++;
            $summary['collections'][] = "kecamatan_collection:both:$zoomBucket";

            $this->warmKecamatanCollectionCache('medan', (int) $zoomBucket);
            $summary['warmed_collection_entries']++;
            $summary['collections'][] = "kecamatan_collection:medan:$zoomBucket";

            $this->warmKecamatanCollectionCache('deli_serdang', (int) $zoomBucket);
            $summary['warmed_collection_entries']++;
            $summary['collections'][] = "kecamatan_collection:deli_serdang:$zoomBucket";
        }

        foreach ($targets as $target) {
            foreach ($polygonZoomBuckets as $zoomBucket) {
                try {
                    $this->warmWilayahPolygonCache((int) $target['id'], (int) $zoomBucket);
                    $summary['warmed_polygon_entries']++;
                    $summary['targets'][] = "{$target['tipe']}:{$target['id']}:polygon:$zoomBucket";
                } catch (\Throwable $e) {
                    $summary['errors'][] = "{$target['id']} polygon z{$zoomBucket}: {$e->getMessage()}";
                }
            }

            if (
                $includeRoads
                && in_array($target['tipe'] ?? '', ['kecamatan', 'kelurahan', 'desa'], true)
            ) {
                try {
                    $this->roadService->getRoadFeatureCollection((int) $target['id'], $roadsZoomBucket, true);
                    $summary['warmed_road_entries']++;
                    $summary['targets'][] = "{$target['tipe']}:{$target['id']}:roads:$roadsZoomBucket";
                } catch (\Throwable $e) {
                    $summary['errors'][] = "{$target['id']} roads z{$roadsZoomBucket}: {$e->getMessage()}";
                }
            }
        }

        return $summary;
    }

    private function warmWilayahPolygonCache(int $wilayahId, int $zoomBucket): void
    {
        $this->cacheService->remember(
            sprintf('wilayah_polygon:%d:%d', $wilayahId, $zoomBucket),
            fn() => $this->wilayahModel->getFeatureCollectionById($wilayahId, $zoomBucket),
            [
                'cache_type' => 'wilayah_polygon',
                'entity_id' => $wilayahId,
                'zoom_bucket' => $zoomBucket,
            ],
            720
        );
    }

    private function warmKecamatanCollectionCache(?string $wilayah, int $zoomBucket): void
    {
        $scopeKey = $wilayah ?? 'both';

        $this->cacheService->remember(
            sprintf('kecamatan_collection:%s:%d', $scopeKey, $zoomBucket),
            fn(): array => $this->kecamatanModel->getFeatureCollectionByWilayah($wilayah, $zoomBucket),
            [
                'cache_type' => 'kecamatan_collection',
                'scope' => $scopeKey,
                'zoom_bucket' => $zoomBucket,
            ],
            720
        );
    }

    /**
     * @param list<int> $targetWilayahIds
     * @param list<array<string, mixed>> $topLevels
     * @param list<array<string, mixed>> $kecamatanList
     * @param list<array<string, mixed>> $leafList
     * @return list<array<string, mixed>>
     */
    private function resolveTargets(
        array $targetWilayahIds,
        array $topLevels,
        array $kecamatanList,
        array $leafList
    ): array {
        if ($targetWilayahIds === []) {
            return array_values(array_merge($topLevels, $kecamatanList, $leafList));
        }

        $rows = $this->wilayahModel
            ->select('id, nama, tipe, parent_id, wilayah')
            ->whereIn('id', $targetWilayahIds)
            ->findAll();

        return array_values(array_filter(
            $rows,
            static fn(array $row): bool => isset($row['id'], $row['tipe'])
        ));
    }
}
