<?php

namespace App\Services;

use App\Models\WilayahAdministrasiModel;
use Config\Database;

class WilayahRoadService
{
    private const ROAD_TABLE_BY_WILAYAH = [
        'medan' => 'gis_roads_medan',
        'deli_serdang' => 'gis_roads_deli_serdang',
    ];

    public function __construct(
        private readonly WilayahAdministrasiModel $wilayahModel = new WilayahAdministrasiModel(),
        private readonly GeoJsonCacheService $cacheService = new GeoJsonCacheService()
    ) {
    }

    public function getRoadFeatureCollection(int $wilayahId, int $zoom = 15, bool $compact = false): ?array
    {
        $wilayah = $this->wilayahModel->find($wilayahId);
        if ($wilayah === null) {
            return null;
        }

        $table = self::ROAD_TABLE_BY_WILAYAH[$wilayah['wilayah']] ?? null;
        if ($table === null) {
            return [
                'type' => 'FeatureCollection',
                'features' => [],
            ];
        }

        $zoomBucket = $this->normalizeZoomBucket($zoom);
        $cacheKey = sprintf(
            'wilayah_roads:%d:%d:%s',
            $wilayahId,
            $zoomBucket,
            $compact ? 'compact' : 'full'
        );

        return $this->cacheService->remember(
            $cacheKey,
            fn(): array => $this->buildRoadFeatureCollection($wilayahId, $table, $zoomBucket, $compact),
            [
                'cache_type' => 'wilayah_roads',
                'entity_id' => $wilayahId,
                'zoom_bucket' => $zoomBucket,
                'scope' => $compact ? 'compact' : 'full',
            ],
            720
        );
    }

    private function buildRoadFeatureCollection(
        int $wilayahId,
        string $table,
        int $zoomBucket,
        bool $compact
    ): array
    {
        [$highwayTypes, $simplifyTolerance] = $this->getZoomProfile($zoomBucket);
        $binds = [$wilayahId, $simplifyTolerance, $simplifyTolerance];

        $roadTypeCondition = '';
        if ($highwayTypes !== []) {
            $placeholders = implode(', ', array_fill(0, count($highwayTypes), '?'));
            $roadTypeCondition = "AND COALESCE(r.properties->>'highway', '') IN ({$placeholders})";
            array_push($binds, ...$highwayTypes);
        }

        $db = Database::connect();
        $sql = $compact
            ? <<<SQL
            WITH selected_wilayah AS (
                SELECT id, nama, tipe, wilayah, geom
                FROM wilayah_administrasi
                WHERE id = ?
            ),
            clipped_roads AS (
                SELECT
                    COALESCE(r.properties->>'highway', 'road') AS highway,
                    ST_Multi(
                        ST_CollectionExtract(
                            CASE
                                WHEN ? > 0
                                    THEN ST_SimplifyPreserveTopology(
                                        ST_Intersection(r.geom, w.geom),
                                        ?
                                    )
                                ELSE ST_Intersection(r.geom, w.geom)
                            END,
                            2
                        )
                    ) AS geom
                FROM {$table} AS r
                CROSS JOIN selected_wilayah AS w
                WHERE r.geom && w.geom
                  AND ST_Intersects(r.geom, w.geom)
                  {$roadTypeCondition}
            ),
            aggregated_roads AS (
                SELECT
                    ROW_NUMBER() OVER (ORDER BY highway) AS feature_id,
                    highway,
                    COUNT(*) AS segment_count,
                    ST_Multi(ST_LineMerge(ST_Collect(geom))) AS geom
                FROM clipped_roads
                WHERE NOT ST_IsEmpty(geom)
                GROUP BY highway
            )
            SELECT json_build_object(
                'type', 'FeatureCollection',
                'features', COALESCE(
                    json_agg(
                        json_build_object(
                            'type', 'Feature',
                            'id', feature_id,
                            'properties', jsonb_strip_nulls(
                                jsonb_build_object(
                                    'highway', highway,
                                    'segment_count', segment_count
                                )
                            ),
                            'geometry', ST_AsGeoJSON(geom, 5)::json
                        )
                        ORDER BY feature_id
                    ) FILTER (WHERE NOT ST_IsEmpty(geom)),
                    '[]'::json
                )
            ) AS geojson
            FROM aggregated_roads
            SQL
            : <<<SQL
            WITH selected_wilayah AS (
                SELECT id, nama, tipe, wilayah, geom
                FROM wilayah_administrasi
                WHERE id = ?
            ),
            clipped_roads AS (
                SELECT
                    r.id,
                    r.source_id,
                    r.name,
                    r.properties,
                    ST_Multi(
                        ST_CollectionExtract(
                            CASE
                                WHEN ? > 0
                                    THEN ST_SimplifyPreserveTopology(
                                        ST_Intersection(r.geom, w.geom),
                                        ?
                                    )
                                ELSE ST_Intersection(r.geom, w.geom)
                            END,
                            2
                        )
                    ) AS geom
                FROM {$table} AS r
                CROSS JOIN selected_wilayah AS w
                WHERE r.geom && w.geom
                  AND ST_Intersects(r.geom, w.geom)
                  {$roadTypeCondition}
            )
            SELECT json_build_object(
                'type', 'FeatureCollection',
                'features', COALESCE(
                    json_agg(
                        json_build_object(
                            'type', 'Feature',
                            'id', id,
                            'properties', jsonb_strip_nulls(
                                jsonb_build_object(
                                    'source_id', source_id,
                                    'name', name,
                                    'highway', properties->>'highway'
                                )
                            ),
                            'geometry', ST_AsGeoJSON(geom, 5)::json
                        )
                        ORDER BY id
                    ) FILTER (WHERE NOT ST_IsEmpty(geom)),
                    '[]'::json
                )
            ) AS geojson
            FROM clipped_roads
        SQL;

        $row = $db->query($sql, $binds)->getRowArray();

        return json_decode($row['geojson'] ?? '{"type":"FeatureCollection","features":[]}', true) ?? [
            'type' => 'FeatureCollection',
                'features' => [],
            ];
    }

    public function normalizeZoomBucket(int $zoom): int
    {
        if ($zoom >= 15) {
            return 15;
        }

        if ($zoom >= 13) {
            return 13;
        }

        return 12;
    }

    /**
     * @return array{0: list<string>, 1: float}
     */
    private function getZoomProfile(int $zoom): array
    {
        if ($zoom >= 15) {
            return [[], 0.0];
        }

        if ($zoom >= 13) {
            return [[
                'motorway',
                'motorway_link',
                'trunk',
                'trunk_link',
                'primary',
                'primary_link',
                'secondary',
                'secondary_link',
                'tertiary',
                'tertiary_link',
                'residential',
                'living_street',
                'unclassified',
                'service',
            ], 0.00006];
        }

        return [[
            'motorway',
            'motorway_link',
            'trunk',
            'trunk_link',
            'primary',
            'primary_link',
            'secondary',
            'secondary_link',
            'tertiary',
            'tertiary_link',
        ], 0.00015];
    }
}
