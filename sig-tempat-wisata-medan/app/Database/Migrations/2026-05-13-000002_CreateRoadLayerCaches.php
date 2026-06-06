<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateRoadLayerCaches extends Migration
{
    public function up()
    {
        $statements = [
            <<<SQL
            CREATE TABLE IF NOT EXISTS gis_roads_medan_cache (
                id BIGSERIAL PRIMARY KEY,
                source_id VARCHAR(100) NULL,
                name VARCHAR(255) NULL,
                properties JSONB NOT NULL DEFAULT '{}'::jsonb,
                geom geometry(MultiLineString, 4326) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            SQL,
            <<<SQL
            CREATE TABLE IF NOT EXISTS gis_roads_deli_serdang_cache (
                id BIGSERIAL PRIMARY KEY,
                source_id VARCHAR(100) NULL,
                name VARCHAR(255) NULL,
                properties JSONB NOT NULL DEFAULT '{}'::jsonb,
                geom geometry(MultiLineString, 4326) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            SQL,
            'CREATE INDEX IF NOT EXISTS idx_gis_roads_medan_cache_geom ON gis_roads_medan_cache USING GIST (geom)',
            'CREATE INDEX IF NOT EXISTS idx_gis_roads_deli_serdang_cache_geom ON gis_roads_deli_serdang_cache USING GIST (geom)',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $statements = [
            'DROP TABLE IF EXISTS gis_roads_deli_serdang_cache',
            'DROP TABLE IF EXISTS gis_roads_medan_cache',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }
}
