<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateGeoSpatialLayers extends Migration
{
    public function up()
    {
        $statements = [
            'CREATE EXTENSION IF NOT EXISTS postgis',
            <<<SQL
            CREATE TABLE IF NOT EXISTS gis_roads_medan (
                id BIGSERIAL PRIMARY KEY,
                source_id VARCHAR(100) NULL,
                name VARCHAR(255) NULL,
                properties JSONB NOT NULL DEFAULT '{}'::jsonb,
                geom geometry(MultiLineString, 4326) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            SQL,
            <<<SQL
            CREATE TABLE IF NOT EXISTS gis_roads_deli_serdang (
                id BIGSERIAL PRIMARY KEY,
                source_id VARCHAR(100) NULL,
                name VARCHAR(255) NULL,
                properties JSONB NOT NULL DEFAULT '{}'::jsonb,
                geom geometry(MultiLineString, 4326) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            SQL,
            <<<SQL
            CREATE TABLE IF NOT EXISTS gis_boundaries_medan (
                id BIGSERIAL PRIMARY KEY,
                source_id VARCHAR(100) NULL,
                name VARCHAR(255) NULL,
                properties JSONB NOT NULL DEFAULT '{}'::jsonb,
                geom geometry(MultiPolygon, 4326) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            SQL,
            <<<SQL
            CREATE TABLE IF NOT EXISTS gis_boundaries_deli_serdang (
                id BIGSERIAL PRIMARY KEY,
                source_id VARCHAR(100) NULL,
                name VARCHAR(255) NULL,
                properties JSONB NOT NULL DEFAULT '{}'::jsonb,
                geom geometry(MultiPolygon, 4326) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            SQL,
            'CREATE INDEX IF NOT EXISTS idx_gis_roads_medan_geom ON gis_roads_medan USING GIST (geom)',
            'CREATE INDEX IF NOT EXISTS idx_gis_roads_deli_serdang_geom ON gis_roads_deli_serdang USING GIST (geom)',
            'CREATE INDEX IF NOT EXISTS idx_gis_boundaries_medan_geom ON gis_boundaries_medan USING GIST (geom)',
            'CREATE INDEX IF NOT EXISTS idx_gis_boundaries_deli_serdang_geom ON gis_boundaries_deli_serdang USING GIST (geom)',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $statements = [
            'DROP TABLE IF EXISTS gis_boundaries_deli_serdang',
            'DROP TABLE IF EXISTS gis_boundaries_medan',
            'DROP TABLE IF EXISTS gis_roads_deli_serdang',
            'DROP TABLE IF EXISTS gis_roads_medan',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }
}
