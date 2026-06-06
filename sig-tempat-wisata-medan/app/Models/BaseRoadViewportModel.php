<?php

namespace App\Models;

use CodeIgniter\Model;

abstract class BaseRoadViewportModel extends Model
{
    protected $returnType = 'array';
    protected $useAutoIncrement = true;

    /**
     * @param array{minLng: float, minLat: float, maxLng: float, maxLat: float} $bbox
     */
    public function getFeatureCollectionForViewport(array $bbox, int $zoom): array
    {
        if ($zoom < 12) {
            return $this->emptyFeatureCollection();
        }

        [$highwayTypes, $simplifyTolerance] = $this->getViewportProfile($zoom);
        $queryData = $this->buildViewportQuery($bbox, $simplifyTolerance, $highwayTypes);

        $row = $this->db->query($queryData['sql'], $queryData['binds'])->getRowArray();

        return json_decode($row['geojson'] ?? '{"type":"FeatureCollection","features":[]}', true) ?? $this->emptyFeatureCollection();
    }

    /**
     * @return array{0: list<string>, 1: float}
     */
    protected function getViewportProfile(int $zoom): array
    {
        if ($zoom >= 15) {
            return [[], 0.0];
        }

        if ($zoom >= 14) {
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
            ], 0.00008];
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
        ], 0.00018];
    }

    /**
     * @param array{minLng: float, minLat: float, maxLng: float, maxLat: float} $bbox
     * @param list<string> $highwayTypes
     * @return array{sql: string, binds: list<mixed>}
     */
    protected function buildViewportQuery(array $bbox, float $simplifyTolerance, array $highwayTypes): array
    {
        $binds = [
            $bbox['minLng'],
            $bbox['minLat'],
            $bbox['maxLng'],
            $bbox['maxLat'],
            $simplifyTolerance,
            $simplifyTolerance,
        ];

        $roadTypeCondition = '';
        if ($highwayTypes !== []) {
            $placeholders = implode(', ', array_fill(0, count($highwayTypes), '?'));
            $roadTypeCondition = "AND COALESCE(properties->>'highway', '') IN ({$placeholders})";
            array_push($binds, ...$highwayTypes);
        }

        $sql = <<<SQL
            WITH envelope AS (
                SELECT ST_MakeEnvelope(?, ?, ?, ?, 4326) AS bbox
            ),
            source AS (
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
                                        ST_Intersection(r.geom, envelope.bbox),
                                        ?
                                    )
                                ELSE ST_Intersection(r.geom, envelope.bbox)
                            END,
                            2
                        )
                    ) AS geom
                FROM {$this->table} AS r, envelope
                WHERE r.geom && envelope.bbox
                  AND ST_Intersects(r.geom, envelope.bbox)
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
            FROM source
        SQL;

        return [
            'sql' => $sql,
            'binds' => $binds,
        ];
    }

    protected function emptyFeatureCollection(): array
    {
        return [
            'type' => 'FeatureCollection',
            'features' => [],
        ];
    }
}
