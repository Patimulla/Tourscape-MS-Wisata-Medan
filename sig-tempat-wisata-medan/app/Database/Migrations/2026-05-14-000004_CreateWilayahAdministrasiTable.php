<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateWilayahAdministrasiTable extends Migration
{
    public function up()
    {
        $statements = [
            'CREATE EXTENSION IF NOT EXISTS postgis;',
            <<<'SQL'
            DO $$
            BEGIN
                IF to_regclass('public.kecamatan') IS NOT NULL
                    AND to_regclass('public.backup_kecamatan_before_wilayah_administrasi') IS NULL THEN
                    EXECUTE 'CREATE TABLE backup_kecamatan_before_wilayah_administrasi AS TABLE kecamatan';
                END IF;

                IF to_regclass('public.gis_boundaries_medan') IS NOT NULL
                    AND to_regclass('public.backup_gis_boundaries_medan_before_wilayah_administrasi') IS NULL THEN
                    EXECUTE 'CREATE TABLE backup_gis_boundaries_medan_before_wilayah_administrasi AS TABLE gis_boundaries_medan';
                END IF;

                IF to_regclass('public.gis_boundaries_deli_serdang') IS NOT NULL
                    AND to_regclass('public.backup_gis_boundaries_deli_serdang_before_wilayah_administrasi') IS NULL THEN
                    EXECUTE 'CREATE TABLE backup_gis_boundaries_deli_serdang_before_wilayah_administrasi AS TABLE gis_boundaries_deli_serdang';
                END IF;
            END
            $$;
            SQL,
            <<<'SQL'
            CREATE TABLE IF NOT EXISTS wilayah_administrasi (
                id BIGSERIAL PRIMARY KEY,
                parent_id BIGINT NULL REFERENCES wilayah_administrasi(id) ON DELETE SET NULL,
                nama VARCHAR(255) NOT NULL,
                tipe VARCHAR(32) NOT NULL CHECK (tipe IN ('kota', 'kabupaten', 'kecamatan', 'kelurahan', 'desa')),
                wilayah VARCHAR(32) NOT NULL CHECK (wilayah IN ('medan', 'deli_serdang')),
                source VARCHAR(32) NOT NULL DEFAULT 'osm' CHECK (source IN ('osm', 'gadm')),
                osm_id BIGINT NULL,
                properties JSONB NOT NULL DEFAULT '{}'::jsonb,
                geom geometry(MultiPolygon, 4326) NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            SQL,
            'CREATE INDEX IF NOT EXISTS idx_wilayah_administrasi_geom ON wilayah_administrasi USING GIST (geom);',
            'CREATE INDEX IF NOT EXISTS idx_wilayah_administrasi_parent_id ON wilayah_administrasi (parent_id);',
            'CREATE INDEX IF NOT EXISTS idx_wilayah_administrasi_tipe ON wilayah_administrasi (tipe);',
            'CREATE INDEX IF NOT EXISTS idx_wilayah_administrasi_wilayah ON wilayah_administrasi (wilayah);',
            'CREATE INDEX IF NOT EXISTS idx_wilayah_administrasi_wilayah_tipe ON wilayah_administrasi (wilayah, tipe);',
            'CREATE INDEX IF NOT EXISTS idx_wilayah_administrasi_lower_nama ON wilayah_administrasi (LOWER(nama));',
            'CREATE UNIQUE INDEX IF NOT EXISTS uq_wilayah_administrasi_hierarchy ON wilayah_administrasi (COALESCE(parent_id, 0), wilayah, tipe, LOWER(nama));',
            <<<'SQL'
            CREATE OR REPLACE FUNCTION set_wilayah_administrasi_updated_at()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = CURRENT_TIMESTAMP;
                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
            SQL,
            'DROP TRIGGER IF EXISTS trg_wilayah_administrasi_updated_at ON wilayah_administrasi;',
            <<<'SQL'
            CREATE TRIGGER trg_wilayah_administrasi_updated_at
            BEFORE UPDATE ON wilayah_administrasi
            FOR EACH ROW
            EXECUTE FUNCTION set_wilayah_administrasi_updated_at();
            SQL,
            <<<'SQL'
            DO $$
            BEGIN
                IF to_regclass('public.gis_boundaries_medan') IS NOT NULL THEN
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
                        NULL,
                        COALESCE(NULLIF(name, ''), 'Kota Medan'),
                        'kota',
                        'medan',
                        'osm',
                        NULL,
                        jsonb_strip_nulls(
                            COALESCE(properties, '{}'::jsonb) ||
                            jsonb_build_object(
                                'legacy_table', 'gis_boundaries_medan',
                                'legacy_id', id
                            )
                        ),
                        ST_Multi(geom)
                    FROM gis_boundaries_medan
                    WHERE NOT EXISTS (
                        SELECT 1
                        FROM wilayah_administrasi
                        WHERE tipe = 'kota' AND wilayah = 'medan'
                    )
                    ORDER BY id
                    LIMIT 1;
                END IF;

                IF to_regclass('public.gis_boundaries_deli_serdang') IS NOT NULL THEN
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
                        NULL,
                        COALESCE(NULLIF(name, ''), 'Kabupaten Deli Serdang'),
                        'kabupaten',
                        'deli_serdang',
                        'osm',
                        NULL,
                        jsonb_strip_nulls(
                            COALESCE(properties, '{}'::jsonb) ||
                            jsonb_build_object(
                                'legacy_table', 'gis_boundaries_deli_serdang',
                                'legacy_id', id
                            )
                        ),
                        ST_Multi(geom)
                    FROM gis_boundaries_deli_serdang
                    WHERE NOT EXISTS (
                        SELECT 1
                        FROM wilayah_administrasi
                        WHERE tipe = 'kabupaten' AND wilayah = 'deli_serdang'
                    )
                    ORDER BY id
                    LIMIT 1;
                END IF;
            END
            $$;
            SQL,
            <<<'SQL'
            DO $$
            BEGIN
                IF to_regclass('public.kecamatan') IS NOT NULL THEN
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
                        parent_lookup.id,
                        k.nama_kecamatan,
                        'kecamatan',
                        k.wilayah,
                        'osm',
                        k.osm_id,
                        jsonb_strip_nulls(
                            COALESCE(k.properties, '{}'::jsonb) ||
                            jsonb_build_object(
                                'legacy_table', 'kecamatan',
                                'legacy_id', k.id
                            )
                        ),
                        ST_Multi(k.geom)
                    FROM kecamatan AS k
                    JOIN wilayah_administrasi AS parent_lookup
                        ON parent_lookup.parent_id IS NULL
                       AND parent_lookup.wilayah = k.wilayah
                       AND (
                            (k.wilayah = 'medan' AND parent_lookup.tipe = 'kota')
                            OR
                            (k.wilayah = 'deli_serdang' AND parent_lookup.tipe = 'kabupaten')
                       )
                    WHERE NOT EXISTS (
                        SELECT 1
                        FROM wilayah_administrasi AS wa
                        WHERE wa.tipe = 'kecamatan'
                          AND wa.wilayah = k.wilayah
                          AND LOWER(wa.nama) = LOWER(k.nama_kecamatan)
                    );
                END IF;
            END
            $$;
            SQL,
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $statements = [
            'DROP TRIGGER IF EXISTS trg_wilayah_administrasi_updated_at ON wilayah_administrasi;',
            'DROP FUNCTION IF EXISTS set_wilayah_administrasi_updated_at();',
            'DROP TABLE IF EXISTS wilayah_administrasi;',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }
}
