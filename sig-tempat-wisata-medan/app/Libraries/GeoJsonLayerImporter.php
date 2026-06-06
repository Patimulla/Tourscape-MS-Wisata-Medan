<?php

namespace App\Libraries;

use CodeIgniter\Database\BaseConnection;
use Config\Database;
use RuntimeException;

class GeoJsonLayerImporter
{
    private const TYPE_LINE = 'line';
    private const TYPE_POLYGON = 'polygon';

    private const VALID_TABLES = [
        'gis_roads_medan' => self::TYPE_LINE,
        'gis_roads_deli_serdang' => self::TYPE_LINE,
        'gis_boundaries_medan' => self::TYPE_POLYGON,
        'gis_boundaries_deli_serdang' => self::TYPE_POLYGON,
    ];

    private BaseConnection $db;

    public function __construct(?BaseConnection $db = null)
    {
        $this->db = $db ?? Database::connect();
    }

    public function importLayer(string $table, string $filePath, bool $truncate = true): array
    {
        $expectedType = self::VALID_TABLES[$table] ?? null;
        if ($expectedType === null) {
            throw new RuntimeException("Tabel impor tidak diizinkan: {$table}");
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
            'table' => $table,
            'file' => $filePath,
            'total_features' => count($features),
            'imported_features' => 0,
            'skipped_features' => 0,
            'skipped_geometry_types' => [],
        ];

        $this->db->transException(true)->transStart();

        if ($truncate) {
            $this->db->query("TRUNCATE TABLE {$table} RESTART IDENTITY");
        }

        $batchRows = [];
        $batchParams = [];

        foreach ($features as $feature) {
            $geometry = $feature['geometry'] ?? null;
            $geometryType = $geometry['type'] ?? null;

            if (!$this->isSupportedGeometryType($expectedType, $geometryType)) {
                $stats['skipped_features']++;
                $stats['skipped_geometry_types'][$geometryType ?? 'null'] =
                    ($stats['skipped_geometry_types'][$geometryType ?? 'null'] ?? 0) + 1;
                continue;
            }

            $properties = is_array($feature['properties'] ?? null) ? $feature['properties'] : [];
            $sourceId = $feature['id'] ?? $properties['@id'] ?? null;
            $name = $properties['name'] ?? $properties['name:id'] ?? null;

            $batchRows[] = '(?, ?, ?::jsonb, ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326)))';
            $batchParams[] = $sourceId;
            $batchParams[] = $name;
            $batchParams[] = json_encode($properties, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            $batchParams[] = json_encode($geometry, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

            $stats['imported_features']++;

            if (count($batchRows) >= 250) {
                $this->flushInsertBatch($table, $batchRows, $batchParams);
                $batchRows = [];
                $batchParams = [];
            }
        }

        if ($batchRows !== []) {
            $this->flushInsertBatch($table, $batchRows, $batchParams);
        }

        $this->db->transComplete();

        ksort($stats['skipped_geometry_types']);

        return $stats;
    }

    public function importKecamatanLayer(string $filePath, string $wilayah, bool $truncate = true): array
    {
        if (!in_array($wilayah, ['medan', 'deli_serdang'], true)) {
            throw new RuntimeException("Wilayah kecamatan tidak valid: {$wilayah}");
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
            'file' => $filePath,
            'total_features' => count($features),
            'imported_features' => 0,
            'skipped_features' => 0,
            'skipped_geometry_types' => [],
        ];

        $this->db->transException(true)->transStart();

        if ($truncate) {
            $this->db->query('TRUNCATE TABLE kecamatan RESTART IDENTITY');
        }

        $batchRows = [];
        $batchParams = [];

        foreach ($features as $feature) {
            $geometry = $feature['geometry'] ?? null;
            $geometryType = $geometry['type'] ?? null;

            if (!$this->isSupportedGeometryType(self::TYPE_POLYGON, $geometryType)) {
                $stats['skipped_features']++;
                $stats['skipped_geometry_types'][$geometryType ?? 'null'] =
                    ($stats['skipped_geometry_types'][$geometryType ?? 'null'] ?? 0) + 1;
                continue;
            }

            $properties = is_array($feature['properties'] ?? null) ? $feature['properties'] : [];
            $osmSource = $feature['id'] ?? $properties['@id'] ?? null;
            $osmId = $this->extractNumericOsmId($osmSource);
            $namaKecamatan = $properties['name'] ?? $properties['name:id'] ?? null;

            if ($namaKecamatan === null) {
                $stats['skipped_features']++;
                continue;
            }

            $batchRows[] = '(?, ?, ?, ?::jsonb, ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON(?), 4326)))';
            $batchParams[] = $osmId;
            $batchParams[] = $namaKecamatan;
            $batchParams[] = $wilayah;
            $batchParams[] = json_encode($properties, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
            $batchParams[] = json_encode($geometry, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

            $stats['imported_features']++;

            if (count($batchRows) >= 200) {
                $this->flushKecamatanInsertBatch($batchRows, $batchParams);
                $batchRows = [];
                $batchParams = [];
            }
        }

        if ($batchRows !== []) {
            $this->flushKecamatanInsertBatch($batchRows, $batchParams);
        }

        $this->db->transComplete();

        ksort($stats['skipped_geometry_types']);

        return $stats;
    }

    private function flushInsertBatch(string $table, array $rows, array $params): void
    {
        $sql = "INSERT INTO {$table} (source_id, name, properties, geom) VALUES " . implode(', ', $rows);
        $this->db->query($sql, $params);
    }

    private function flushKecamatanInsertBatch(array $rows, array $params): void
    {
        $sql = 'INSERT INTO kecamatan (osm_id, nama_kecamatan, wilayah, properties, geom) VALUES ' . implode(', ', $rows);
        $this->db->query($sql, $params);
    }

    private function isSupportedGeometryType(string $expectedType, ?string $geometryType): bool
    {
        return match ($expectedType) {
            self::TYPE_LINE => in_array($geometryType, ['LineString', 'MultiLineString'], true),
            self::TYPE_POLYGON => in_array($geometryType, ['Polygon', 'MultiPolygon'], true),
            default => false,
        };
    }

    private function extractNumericOsmId(mixed $source): ?int
    {
        if (is_int($source)) {
            return $source;
        }

        if (!is_string($source) || $source === '') {
            return null;
        }

        if (preg_match('/(\d+)/', $source, $matches) !== 1) {
            return null;
        }

        return (int) $matches[1];
    }
}
