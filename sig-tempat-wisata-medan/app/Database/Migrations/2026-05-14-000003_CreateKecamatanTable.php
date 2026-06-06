<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateKecamatanTable extends Migration
{
    public function up()
    {
        $this->db->query('CREATE EXTENSION IF NOT EXISTS postgis;');

        $this->db->query(<<<SQL
            CREATE TABLE IF NOT EXISTS kecamatan (
                id BIGSERIAL PRIMARY KEY,
                osm_id BIGINT NULL,
                nama_kecamatan VARCHAR(255) NOT NULL,
                wilayah VARCHAR(32) NOT NULL CHECK (wilayah IN ('medan', 'deli_serdang')),
                properties JSONB NOT NULL DEFAULT '{}'::jsonb,
                geom geometry(MultiPolygon, 4326) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        SQL);

        $this->db->query('CREATE INDEX IF NOT EXISTS idx_kecamatan_geom ON kecamatan USING GIST (geom);');
        $this->db->query('CREATE INDEX IF NOT EXISTS idx_kecamatan_wilayah ON kecamatan (wilayah);');
        $this->db->query('CREATE INDEX IF NOT EXISTS idx_kecamatan_nama ON kecamatan (nama_kecamatan);');
    }

    public function down()
    {
        $this->db->query('DROP TABLE IF EXISTS kecamatan;');
    }
}
