<?php

namespace App\Models;

class KecamatanModel extends BaseGeoFeatureModel
{
    protected $table = 'kecamatan';
    protected $allowedFields = ['osm_id', 'nama_kecamatan', 'wilayah', 'properties', 'geom'];

    public function getSummaryList(): array
    {
        return $this->select('id, nama_kecamatan, wilayah')
            ->orderBy('wilayah', 'ASC')
            ->orderBy('nama_kecamatan', 'ASC')
            ->findAll();
    }

    public function getFeatureCollectionByWilayah(?string $wilayah = null, int $zoom = 12): array
    {
        $simplifyTolerance = $this->getSimplifyTolerance($zoom);

        $sql = <<<SQL
            SELECT json_build_object(
                'type', 'FeatureCollection',
                'features', COALESCE(
                    json_agg(
                        json_build_object(
                            'type', 'Feature',
                            'id', id,
                            'properties', jsonb_strip_nulls(
                                jsonb_build_object(
                                    'osm_id', osm_id,
                                    'nama_kecamatan', nama_kecamatan,
                                    'wilayah', wilayah
                                )
                            ),
                            'geometry', ST_AsGeoJSON(
                                CASE
                                    WHEN ? > 0 THEN ST_SimplifyPreserveTopology(geom, ?)
                                    ELSE geom
                                END
                            , 6)::json
                        )
                        ORDER BY wilayah, nama_kecamatan
                    ),
                    '[]'::json
                )
            ) AS geojson
            FROM kecamatan
            WHERE (? IS NULL OR wilayah = ?)
        SQL;

        $row = $this->db->query($sql, [$simplifyTolerance, $simplifyTolerance, $wilayah, $wilayah])->getRowArray();

        return json_decode($row['geojson'] ?? '{"type":"FeatureCollection","features":[]}', true) ?? [
            'type' => 'FeatureCollection',
            'features' => [],
        ];
    }

    public function getFeatureCollectionById(int $id, int $zoom = 15): ?array
    {
        $simplifyTolerance = $this->getSimplifyTolerance($zoom);

        $sql = <<<SQL
            SELECT json_build_object(
                'type', 'FeatureCollection',
                'features', COALESCE(
                    json_agg(
                        json_build_object(
                            'type', 'Feature',
                            'id', id,
                            'properties', jsonb_strip_nulls(
                                jsonb_build_object(
                                    'osm_id', osm_id,
                                    'nama_kecamatan', nama_kecamatan,
                                    'wilayah', wilayah
                                )
                            ),
                            'geometry', ST_AsGeoJSON(
                                CASE
                                    WHEN ? > 0 THEN ST_SimplifyPreserveTopology(geom, ?)
                                    ELSE geom
                                END
                            , 6)::json
                        )
                    ),
                    '[]'::json
                )
            ) AS geojson
            FROM kecamatan
            WHERE id = ?
        SQL;

        $row = $this->db->query($sql, [$simplifyTolerance, $simplifyTolerance, $id])->getRowArray();
        $featureCollection = json_decode($row['geojson'] ?? '', true);

        if (!is_array($featureCollection) || ($featureCollection['features'] ?? []) === []) {
            return null;
        }

        return $featureCollection;
    }

    public function normalizeZoomBucket(int $zoom): int
    {
        if ($zoom >= 15) {
            return 15;
        }

        if ($zoom >= 13) {
            return 13;
        }

        if ($zoom >= 11) {
            return 11;
        }

        return 10;
    }

    private function getSimplifyTolerance(int $zoom): float
    {
        if ($zoom >= 15) {
            return 0.0;
        }

        if ($zoom >= 13) {
            return 0.00003;
        }

        if ($zoom >= 11) {
            return 0.00008;
        }

        return 0.00015;
    }
}
