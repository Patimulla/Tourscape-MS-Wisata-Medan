<?php

namespace App\Services;

use Config\Database;
use DateInterval;
use DateTimeImmutable;

class GeoJsonCacheService
{
    private const DEFAULT_TTL_MINUTES = 720;
    private readonly \CodeIgniter\Database\BaseConnection $db;

    public function __construct(?\CodeIgniter\Database\BaseConnection $db = null)
    {
        $this->db = $db ?? Database::connect();
    }

    public function remember(
        string $cacheKey,
        callable $resolver,
        array $meta = [],
        ?int $ttlMinutes = null
    ): ?array {
        $ttl = max(1, $ttlMinutes ?? self::DEFAULT_TTL_MINUTES);
        $cached = $this->get($cacheKey, $ttl);
        if ($cached !== null) {
            return $cached;
        }

        $resolved = $resolver();
        if (!is_array($resolved)) {
            return null;
        }

        $this->put($cacheKey, $resolved, $meta);

        return $resolved;
    }

    public function get(string $cacheKey, int $ttlMinutes = self::DEFAULT_TTL_MINUTES): ?array
    {
        $threshold = (new DateTimeImmutable())
            ->sub(new DateInterval('PT' . max(1, $ttlMinutes) . 'M'))
            ->format('Y-m-d H:i:s');

        $row = $this->db->query(
            'SELECT geojson FROM gis_web_geojson_cache WHERE cache_key = ? AND updated_at >= ? LIMIT 1',
            [$cacheKey, $threshold]
        )->getRowArray();

        if (!is_array($row) || !array_key_exists('geojson', $row)) {
            return null;
        }

        return $this->normalizeGeoJson($row['geojson']);
    }

    public function put(string $cacheKey, array $geojson, array $meta = []): void
    {
        $featureCount = count($geojson['features'] ?? []);
        $payload = json_encode($geojson, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($payload === false) {
            return;
        }

        $this->db->query(
            <<<'SQL'
            INSERT INTO gis_web_geojson_cache (
                cache_key,
                cache_type,
                entity_id,
                scope,
                zoom_bucket,
                feature_count,
                geojson,
                created_at,
                updated_at
            )
            VALUES (
                ?,
                ?,
                ?,
                ?,
                ?,
                ?,
                CAST(? AS JSONB),
                CURRENT_TIMESTAMP,
                CURRENT_TIMESTAMP
            )
            ON CONFLICT (cache_key) DO UPDATE SET
                cache_type = EXCLUDED.cache_type,
                entity_id = EXCLUDED.entity_id,
                scope = EXCLUDED.scope,
                zoom_bucket = EXCLUDED.zoom_bucket,
                feature_count = EXCLUDED.feature_count,
                geojson = EXCLUDED.geojson,
                updated_at = CURRENT_TIMESTAMP
            SQL,
            [
                $cacheKey,
                $meta['cache_type'] ?? 'generic',
                $meta['entity_id'] ?? null,
                $meta['scope'] ?? null,
                $meta['zoom_bucket'] ?? null,
                $featureCount,
                $payload,
            ]
        );
    }

    public function clearByPrefix(string $prefix): void
    {
        $this->db->query(
            'DELETE FROM gis_web_geojson_cache WHERE cache_key LIKE ?',
            [$prefix . '%']
        );
    }

    private function normalizeGeoJson(mixed $value): ?array
    {
        if (is_array($value)) {
            return $value;
        }

        if (!is_string($value) || trim($value) === '') {
            return null;
        }

        $decoded = json_decode($value, true);

        return is_array($decoded) ? $decoded : null;
    }
}
