<?php

namespace App\Models;

use CodeIgniter\Model;

abstract class BaseGeoFeatureModel extends Model
{
    protected $returnType = 'array';
    protected $useAutoIncrement = true;
    protected ?string $geoJsonGeometryExpression = null;

    public function getFeatureCollection(): array
    {
        $geometryExpression = $this->geoJsonGeometryExpression ?? 'geom';

        $sql = <<<SQL
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
                            'geometry', ST_AsGeoJSON({$geometryExpression})::json
                        )
                        ORDER BY id
                    ),
                    '[]'::json
                )
            ) AS geojson
            FROM {$this->table}
        SQL;

        $row = $this->db->query($sql)->getRowArray();

        return json_decode($row['geojson'] ?? '{"type":"FeatureCollection","features":[]}', true) ?? [
            'type' => 'FeatureCollection',
            'features' => [],
        ];
    }
}
