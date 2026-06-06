<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateWebGeoJsonCacheTable extends Migration
{
    public function up()
    {
        $statements = [
            <<<'SQL'
            CREATE TABLE IF NOT EXISTS gis_web_geojson_cache (
                cache_key VARCHAR(191) PRIMARY KEY,
                cache_type VARCHAR(64) NOT NULL,
                entity_id BIGINT NULL,
                scope VARCHAR(64) NULL,
                zoom_bucket SMALLINT NULL,
                feature_count INTEGER NOT NULL DEFAULT 0,
                geojson JSONB NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            SQL,
            'CREATE INDEX IF NOT EXISTS idx_gis_web_geojson_cache_type_entity_zoom ON gis_web_geojson_cache (cache_type, entity_id, zoom_bucket);',
            'CREATE INDEX IF NOT EXISTS idx_gis_web_geojson_cache_type_scope_zoom ON gis_web_geojson_cache (cache_type, scope, zoom_bucket);',
            'CREATE INDEX IF NOT EXISTS idx_gis_web_geojson_cache_updated_at ON gis_web_geojson_cache (updated_at);',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $this->db->query('DROP TABLE IF EXISTS gis_web_geojson_cache;');
    }
}
