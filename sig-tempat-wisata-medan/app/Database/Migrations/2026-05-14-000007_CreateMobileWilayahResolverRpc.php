<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateMobileWilayahResolverRpc extends Migration
{
    public function up()
    {
        $statements = [
            <<<'SQL'
            CREATE OR REPLACE FUNCTION mobile_resolve_wilayah_from_point(
                p_lat DOUBLE PRECISION,
                p_lng DOUBLE PRECISION
            )
            RETURNS JSONB
            LANGUAGE sql
            STABLE
            SECURITY INVOKER
            SET search_path = public
            AS $$
                WITH input_point AS (
                    SELECT ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326) AS geom
                ),
                matched_leaf AS (
                    SELECT
                        w.id,
                        w.nama,
                        w.tipe,
                        w.parent_id,
                        w.wilayah
                    FROM wilayah_administrasi AS w
                    CROSS JOIN input_point AS p
                    WHERE w.tipe IN ('kelurahan', 'desa')
                      AND w.geom && p.geom
                      AND (ST_Contains(w.geom, p.geom) OR ST_Intersects(w.geom, p.geom))
                    ORDER BY
                        CASE WHEN ST_Contains(w.geom, p.geom) THEN 0 ELSE 1 END,
                        ST_Area(w.geom) ASC,
                        w.id ASC
                    LIMIT 1
                ),
                fallback_kecamatan AS (
                    SELECT
                        w.id,
                        w.nama,
                        w.tipe,
                        w.parent_id,
                        w.wilayah
                    FROM wilayah_administrasi AS w
                    CROSS JOIN input_point AS p
                    WHERE w.tipe = 'kecamatan'
                      AND w.geom && p.geom
                      AND (ST_Contains(w.geom, p.geom) OR ST_Intersects(w.geom, p.geom))
                    ORDER BY
                        CASE WHEN ST_Contains(w.geom, p.geom) THEN 0 ELSE 1 END,
                        ST_Area(w.geom) ASC,
                        w.id ASC
                    LIMIT 1
                ),
                matched_kecamatan AS (
                    SELECT
                        w.id,
                        w.nama,
                        w.tipe,
                        w.parent_id,
                        w.wilayah
                    FROM wilayah_administrasi AS w
                    WHERE w.id = (SELECT parent_id FROM matched_leaf LIMIT 1)
                    UNION ALL
                    SELECT *
                    FROM fallback_kecamatan
                    WHERE NOT EXISTS (SELECT 1 FROM matched_leaf)
                ),
                fallback_top_level AS (
                    SELECT
                        w.id,
                        w.nama,
                        w.tipe,
                        w.parent_id,
                        w.wilayah
                    FROM wilayah_administrasi AS w
                    CROSS JOIN input_point AS p
                    WHERE w.tipe IN ('kota', 'kabupaten')
                      AND w.geom && p.geom
                      AND (ST_Contains(w.geom, p.geom) OR ST_Intersects(w.geom, p.geom))
                    ORDER BY
                        CASE WHEN ST_Contains(w.geom, p.geom) THEN 0 ELSE 1 END,
                        ST_Area(w.geom) ASC,
                        w.id ASC
                    LIMIT 1
                ),
                matched_top_level AS (
                    SELECT
                        w.id,
                        w.nama,
                        w.tipe,
                        w.parent_id,
                        w.wilayah
                    FROM wilayah_administrasi AS w
                    WHERE w.id = (SELECT parent_id FROM matched_kecamatan LIMIT 1)
                    UNION ALL
                    SELECT *
                    FROM fallback_top_level
                    WHERE NOT EXISTS (SELECT 1 FROM matched_kecamatan)
                )
                SELECT jsonb_build_object(
                    'matched',
                    (
                        EXISTS (SELECT 1 FROM matched_top_level)
                        OR EXISTS (SELECT 1 FROM matched_kecamatan)
                        OR EXISTS (SELECT 1 FROM matched_leaf)
                    ),
                    'top_level',
                    (
                        SELECT jsonb_build_object(
                            'id', id,
                            'nama', nama,
                            'tipe', tipe,
                            'parent_id', parent_id,
                            'wilayah', wilayah
                        )
                        FROM matched_top_level
                        LIMIT 1
                    ),
                    'kecamatan',
                    (
                        SELECT jsonb_build_object(
                            'id', id,
                            'nama', nama,
                            'tipe', tipe,
                            'parent_id', parent_id,
                            'wilayah', wilayah
                        )
                        FROM matched_kecamatan
                        LIMIT 1
                    ),
                    'leaf',
                    (
                        SELECT jsonb_build_object(
                            'id', id,
                            'nama', nama,
                            'tipe', tipe,
                            'parent_id', parent_id,
                            'wilayah', wilayah
                        )
                        FROM matched_leaf
                        LIMIT 1
                    )
                )
            $$;
            SQL,
            'REVOKE ALL ON FUNCTION mobile_resolve_wilayah_from_point(DOUBLE PRECISION, DOUBLE PRECISION) FROM PUBLIC;',
            'GRANT EXECUTE ON FUNCTION mobile_resolve_wilayah_from_point(DOUBLE PRECISION, DOUBLE PRECISION) TO anon, authenticated;',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $this->db->query('DROP FUNCTION IF EXISTS mobile_resolve_wilayah_from_point(DOUBLE PRECISION, DOUBLE PRECISION);');
    }
}
