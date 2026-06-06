<?php

namespace App\Libraries;

use CodeIgniter\Database\BaseConnection;
use Config\Database;
use RuntimeException;

class WilayahAdministrasiImporter
{
    private BaseConnection $db;

    public function __construct(?BaseConnection $db = null)
    {
        $this->db = $db ?? Database::connect();
    }

    public function importLeafLayer(
        string $filePath,
        string $wilayah,
        string $source,
        ?string $forcedType = null
    ): array {
        if (!in_array($wilayah, ['medan', 'deli_serdang'], true)) {
            throw new RuntimeException("Wilayah impor tidak valid: {$wilayah}");
        }

        if (!in_array($source, ['osm', 'gadm'], true)) {
            throw new RuntimeException("Source impor tidak valid: {$source}");
        }

        if ($forcedType !== null && !in_array($forcedType, ['kelurahan', 'desa'], true)) {
            throw new RuntimeException("Tipe wilayah tidak valid: {$forcedType}");
        }

        if (!is_file($filePath)) {
            throw new RuntimeException("File GeoJSON tidak ditemukan: {$filePath}");
        }

        $decoded = json_decode((string) file_get_contents($filePath), true);
        if (!is_array($decoded) || ($decoded['type'] ?? null) !== 'FeatureCollection') {
            throw new RuntimeException("File bukan GeoJSON FeatureCollection yang valid: {$filePath}");
        }

        $features = $decoded['features'] ?? [];
        if (!is_array($features)) {
            throw new RuntimeException("FeatureCollection tidak memiliki array features yang valid: {$filePath}");
        }

        $stats = [
            'wilayah' => $wilayah,
            'source' => $source,
            'file' => $filePath,
            'total_features' => count($features),
            'prepared_features' => 0,
            'inserted_features' => 0,
            'skipped_features' => 0,
            'skipped_geometry_types' => [],
            'unresolved_parent_rows' => 0,
        ];

        $this->db->transException(true)->transStart();
        $this->createTempImportTable();

        $batchRows = [];
        $batchParams = [];

        foreach ($features as $feature) {
            $geometry = $feature['geometry'] ?? null;
            $geometryType = $geometry['type'] ?? null;

            if (!in_array($geometryType, ['Polygon', 'MultiPolygon'], true)) {
                $stats['skipped_features']++;
                $stats['skipped_geometry_types'][$geometryType ?? 'null'] =
                    ($stats['skipped_geometry_types'][$geometryType ?? 'null'] ?? 0) + 1;
                continue;
            }

            $properties = is_array($feature['properties'] ?? null) ? $feature['properties'] : [];
            $normalized = $this->normalizeFeature($feature, $properties, $wilayah, $source, $forcedType);

            if ($normalized === null) {
                $stats['skipped_features']++;
                continue;
            }

            $batchRows[] = '(?, ?, ?, ?, ?, ?, ?::jsonb, ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326)))';
            array_push(
                $batchParams,
                $normalized['nama'],
                $normalized['tipe'],
                $normalized['wilayah'],
                $normalized['source'],
                $normalized['osm_id'],
                $normalized['parent_name_hint'],
                json_encode($normalized['properties'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                json_encode($geometry, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)
            );

            $stats['prepared_features']++;

            if (count($batchRows) >= 200) {
                $this->flushTempBatch($batchRows, $batchParams);
                $batchRows = [];
                $batchParams = [];
            }
        }

        if ($batchRows !== []) {
            $this->flushTempBatch($batchRows, $batchParams);
        }

        $stats['unresolved_parent_rows'] = $this->countUnresolvedParents();
        $stats['inserted_features'] = $this->insertIntoFinalTable();

        $this->db->transComplete();
        ksort($stats['skipped_geometry_types']);

        return $stats;
    }

    private function createTempImportTable(): void
    {
        $this->db->query(<<<'SQL'
            CREATE TEMP TABLE tmp_wilayah_administrasi_import (
                nama VARCHAR(255) NOT NULL,
                tipe VARCHAR(32) NOT NULL,
                wilayah VARCHAR(32) NOT NULL,
                source VARCHAR(32) NOT NULL,
                osm_id BIGINT NULL,
                parent_name_hint VARCHAR(255) NULL,
                properties JSONB NOT NULL DEFAULT '{}'::jsonb,
                geom geometry(MultiPolygon, 4326) NOT NULL
            ) ON COMMIT DROP;
        SQL);
    }

    private function flushTempBatch(array $rows, array $params): void
    {
        $sql = 'INSERT INTO tmp_wilayah_administrasi_import (nama, tipe, wilayah, source, osm_id, parent_name_hint, properties, geom) VALUES '
            . implode(', ', $rows);

        $this->db->query($sql, $params);
    }

    private function countUnresolvedParents(): int
    {
        $sql = <<<'SQL'
            WITH resolved AS (
                SELECT
                    tmp.nama,
                    matched_parent.id AS parent_id
                FROM tmp_wilayah_administrasi_import AS tmp
                LEFT JOIN LATERAL (
                    SELECT p.id
                    FROM wilayah_administrasi AS p
                    WHERE p.tipe = 'kecamatan'
                      AND p.wilayah = tmp.wilayah
                      AND (
                          (tmp.parent_name_hint IS NOT NULL AND LOWER(p.nama) = LOWER(tmp.parent_name_hint))
                          OR ST_Contains(p.geom, ST_PointOnSurface(tmp.geom))
                          OR ST_Intersects(p.geom, tmp.geom)
                      )
                    ORDER BY
                        CASE
                            WHEN tmp.parent_name_hint IS NOT NULL AND LOWER(p.nama) = LOWER(tmp.parent_name_hint) THEN 0
                            WHEN ST_Contains(p.geom, ST_PointOnSurface(tmp.geom)) THEN 1
                            ELSE 2
                        END,
                        COALESCE(ST_Area(ST_Intersection(p.geom, tmp.geom)), 0) DESC
                    LIMIT 1
                ) AS matched_parent ON TRUE
            )
            SELECT COUNT(*)
            FROM resolved
            WHERE parent_id IS NULL
        SQL;

        $row = $this->db->query($sql)->getRowArray();

        return (int) ($row['count'] ?? 0);
    }

    private function insertIntoFinalTable(): int
    {
        $sql = <<<'SQL'
            INSERT INTO wilayah_administrasi (
                parent_id,
                nama,
                tipe,
                wilayah,
                source,
                osm_id,
                properties,
                geom
            )
            SELECT
                matched_parent.id,
                tmp.nama,
                tmp.tipe,
                tmp.wilayah,
                tmp.source,
                tmp.osm_id,
                jsonb_strip_nulls(
                    COALESCE(tmp.properties, '{}'::jsonb) ||
                    CASE
                        WHEN tmp.parent_name_hint IS NOT NULL THEN jsonb_build_object('parent_name_hint', tmp.parent_name_hint)
                        ELSE '{}'::jsonb
                    END
                ),
                ST_Multi(tmp.geom)
            FROM tmp_wilayah_administrasi_import AS tmp
            LEFT JOIN LATERAL (
                SELECT p.id
                FROM wilayah_administrasi AS p
                WHERE p.tipe = 'kecamatan'
                  AND p.wilayah = tmp.wilayah
                  AND (
                      (tmp.parent_name_hint IS NOT NULL AND LOWER(p.nama) = LOWER(tmp.parent_name_hint))
                      OR ST_Contains(p.geom, ST_PointOnSurface(tmp.geom))
                      OR ST_Intersects(p.geom, tmp.geom)
                  )
                ORDER BY
                    CASE
                        WHEN tmp.parent_name_hint IS NOT NULL AND LOWER(p.nama) = LOWER(tmp.parent_name_hint) THEN 0
                        WHEN ST_Contains(p.geom, ST_PointOnSurface(tmp.geom)) THEN 1
                        ELSE 2
                    END,
                    COALESCE(ST_Area(ST_Intersection(p.geom, tmp.geom)), 0) DESC
                LIMIT 1
            ) AS matched_parent ON TRUE
            ON CONFLICT DO NOTHING
        SQL;

        $this->db->query($sql);

        return $this->db->affectedRows();
    }

    /**
     * @return array<string, mixed>|null
     */
    private function normalizeFeature(
        array $feature,
        array $properties,
        string $wilayah,
        string $source,
        ?string $forcedType
    ): ?array {
        $nama = trim((string) (
            $properties['name']
            ?? $properties['NAME_4']
            ?? $properties['name:id']
            ?? ''
        ));

        if ($nama === '') {
            return null;
        }

        $tipe = $forcedType ?? $this->normalizeLeafType($properties['TYPE_4'] ?? $properties['type'] ?? null);
        if (!in_array($tipe, ['kelurahan', 'desa'], true)) {
            return null;
        }

        $parentNameHint = null;
        if (isset($properties['NAME_3']) && is_string($properties['NAME_3']) && trim($properties['NAME_3']) !== '') {
            $parentNameHint = trim($properties['NAME_3']);
        } else {
            $parentNameHint = $this->extractParentFromWikipedia($properties['wikipedia'] ?? null);
        }

        $osmSource = $feature['id'] ?? $properties['@id'] ?? $properties['GID_4'] ?? null;

        return [
            'nama' => $nama,
            'tipe' => $tipe,
            'wilayah' => $wilayah,
            'source' => $source,
            'osm_id' => $source === 'osm' ? $this->extractNumericId($osmSource) : null,
            'parent_name_hint' => $parentNameHint,
            'properties' => $properties,
        ];
    }

    private function normalizeLeafType(mixed $rawType): ?string
    {
        if (!is_string($rawType) || trim($rawType) === '') {
            return null;
        }

        $normalized = mb_strtolower(trim($rawType));

        return match ($normalized) {
            'kelurahan' => 'kelurahan',
            'desa' => 'desa',
            default => null,
        };
    }

    private function extractParentFromWikipedia(mixed $rawWikipedia): ?string
    {
        if (!is_string($rawWikipedia) || trim($rawWikipedia) === '') {
            return null;
        }

        $normalized = preg_replace('/^[a-z]{2}:/i', '', trim($rawWikipedia));
        if ($normalized === null) {
            return null;
        }

        $parts = array_values(array_filter(array_map('trim', explode(',', $normalized))));

        return $parts[1] ?? null;
    }

    private function extractNumericId(mixed $rawId): ?int
    {
        if (is_int($rawId)) {
            return $rawId;
        }

        if (!is_string($rawId) || trim($rawId) === '') {
            return null;
        }

        if (preg_match('/(\d+)/', $rawId, $matches) !== 1) {
            return null;
        }

        return (int) $matches[1];
    }
}
