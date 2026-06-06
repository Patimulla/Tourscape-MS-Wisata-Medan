<?php

namespace App\Services;

use App\Models\KecamatanModel;
use Config\Database;

class KecamatanRoadService
{
    private const ROAD_TABLE_BY_WILAYAH = [
        'medan' => 'gis_roads_medan',
        'deli_serdang' => 'gis_roads_deli_serdang',
    ];

    public function __construct(
        private readonly KecamatanModel $kecamatanModel = new KecamatanModel()
    ) {
    }

    public function getRoadFeatureCollection(int $kecamatanId, int $zoom = 15): ?array
    {
        $kecamatan = $this->kecamatanModel->find($kecamatanId);
        if ($kecamatan === null) {
            return null;
        }

        [$highwayTypes, $simplifyTolerance] = $this->getZoomProfile($zoom);
        $table = self::ROAD_TABLE_BY_WILAYAH[$kecamatan['wilayah']] ?? null;
        if ($table === null) {
            return [
                'type' => 'FeatureCollection',
                'features' => [],
            ];
        }

        $binds = [$kecamatanId, $simplifyTolerance, $simplifyTolerance];
        $roadTypeCondition = '';
        if ($highwayTypes !== []) {
            $placeholders = implode(', ', array_fill(0, count($highwayTypes), '?'));
            $roadTypeCondition = "AND COALESCE(r.properties->>'highway', '') IN ({$placeholders})";
            array_push($binds, ...$highwayTypes);
        }

        $db = Database::connect();
        $sql = <<<SQL
            WITH selected_kecamatan AS (
                SELECT id, nama_kecamatan, wilayah, geom
                FROM kecamatan
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
                                        ST_Intersection(r.geom, k.geom),
                                        ?
                                    )
                                ELSE ST_Intersection(r.geom, k.geom)
                            END,
                            2
                        )
                    ) AS geom
                FROM {$table} AS r
                CROSS JOIN selected_kecamatan AS k
                WHERE r.geom && k.geom
                  AND ST_Intersects(r.geom, k.geom)
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
                                COALESCE(properties, '{}'::jsonb) ||
                                CASE
                                    WHEN source_id IS NOT NULL THEN jsonb_build_object('source_id', source_id)
                                    ELSE '{}'::jsonb
                                END ||
                                CASE
                                    WHEN name IS NOT NULL THEN jsonb_build_object('name', name)
                                    ELSE '{}'::jsonb
                                END
                            ),
                            'geometry', ST_AsGeoJSON(geom)::json
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
