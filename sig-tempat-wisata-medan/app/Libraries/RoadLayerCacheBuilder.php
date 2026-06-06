<?php

namespace App\Libraries;

use CodeIgniter\Database\BaseConnection;
use Config\Database;
use RuntimeException;

class RoadLayerCacheBuilder
{
    private const CONFIG = [
        'gis_roads_medan' => [
            'cache_table' => 'gis_roads_medan_cache',
            'name' => 'Jalan Kota Medan',
        ],
        'gis_roads_deli_serdang' => [
            'cache_table' => 'gis_roads_deli_serdang_cache',
            'name' => 'Jalan Deli Serdang',
        ],
    ];

    private BaseConnection $db;

    public function __construct(?BaseConnection $db = null)
    {
        $this->db = $db ?? Database::connect();
    }

    public function rebuildAll(): array
    {
        $results = [];
        foreach (array_keys(self::CONFIG) as $sourceTable) {
            $results[] = $this->rebuild($sourceTable);
        }

        return $results;
    }

    public function rebuild(string $sourceTable): array
    {
        $config = self::CONFIG[$sourceTable] ?? null;
        if ($config === null) {
            throw new RuntimeException("Source table tidak didukung: {$sourceTable}");
        }

        $cacheTable = $config['cache_table'];
        $name = $config['name'];

        $this->db->transException(true)->transStart();
        $this->db->query("TRUNCATE TABLE {$cacheTable} RESTART IDENTITY");

        $sql = <<<SQL
            INSERT INTO {$cacheTable} (source_id, name, properties, geom)
            SELECT
                ?,
                ?,
                jsonb_build_object(
                    'source_layer', ?,
                    'feature_count', COUNT(*),
                    'cached', true
                ),
                ST_Multi(
                    ST_LineMerge(
                        ST_Collect(
                            ST_Simplify(
                                ST_SnapToGrid(geom, 0.00005),
                                0.00005
                            )
                        )
                    )
                ) AS geom
            FROM {$sourceTable}
        SQL;

        $this->db->query($sql, [$sourceTable, $name, $sourceTable]);
        $this->db->transComplete();

        $row = $this->db->query(
            "SELECT (SELECT COUNT(*) FROM {$cacheTable}) AS total_rows, GeometryType(geom) AS geom_type, ST_SRID(geom) AS srid FROM {$cacheTable} LIMIT 1"
        )->getRowArray();

        return [
            'source_table' => $sourceTable,
            'cache_table' => $cacheTable,
            'cache_rows' => (int) ($row['total_rows'] ?? 0),
            'geom_type' => $row['geom_type'] ?? null,
            'srid' => isset($row['srid']) ? (int) $row['srid'] : null,
        ];
    }
}
