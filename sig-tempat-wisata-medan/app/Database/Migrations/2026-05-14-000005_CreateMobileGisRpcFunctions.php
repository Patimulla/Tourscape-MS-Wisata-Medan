<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateMobileGisRpcFunctions extends Migration
{
    public function up()
    {
        $statements = [
            <<<'SQL'
            CREATE OR REPLACE FUNCTION mobile_top_level_wilayah()
            RETURNS TABLE (
                id BIGINT,
                nama TEXT,
                tipe TEXT,
                parent_id BIGINT,
                wilayah TEXT
            )
            LANGUAGE sql
            STABLE
            SECURITY INVOKER
            SET search_path = public
            AS $$
                SELECT
                    w.id,
                    w.nama,
                    w.tipe,
                    w.parent_id,
                    w.wilayah
                FROM wilayah_administrasi AS w
                WHERE w.tipe IN ('kota', 'kabupaten')
                ORDER BY w.wilayah ASC, w.tipe ASC, w.nama ASC
            $$;
            SQL,
            <<<'SQL'
            CREATE OR REPLACE FUNCTION mobile_wilayah_children(
                p_parent_id BIGINT,
                p_tipe TEXT DEFAULT NULL
            )
            RETURNS TABLE (
                id BIGINT,
                nama TEXT,
                tipe TEXT,
                parent_id BIGINT,
                wilayah TEXT
            )
            LANGUAGE sql
            STABLE
            SECURITY INVOKER
            SET search_path = public
            AS $$
                SELECT
                    w.id,
                    w.nama,
                    w.tipe,
                    w.parent_id,
                    w.wilayah
                FROM wilayah_administrasi AS w
                WHERE w.parent_id = p_parent_id
                  AND (p_tipe IS NULL OR w.tipe = p_tipe)
                ORDER BY w.tipe ASC, w.nama ASC
            $$;
            SQL,
            <<<'SQL'
            CREATE OR REPLACE FUNCTION mobile_wilayah_kecamatan(
                p_wilayah_id BIGINT DEFAULT NULL,
                p_wilayah TEXT DEFAULT NULL
            )
            RETURNS TABLE (
                id BIGINT,
                nama TEXT,
                tipe TEXT,
                parent_id BIGINT,
                wilayah TEXT
            )
            LANGUAGE sql
            STABLE
            SECURITY INVOKER
            SET search_path = public
            AS $$
                SELECT
                    w.id,
                    w.nama,
                    w.tipe,
                    w.parent_id,
                    w.wilayah
                FROM wilayah_administrasi AS w
                WHERE w.tipe = 'kecamatan'
                  AND (
                    (p_wilayah_id IS NULL AND p_wilayah IS NULL)
                    OR (p_wilayah_id IS NOT NULL AND w.parent_id = p_wilayah_id)
                    OR (p_wilayah_id IS NULL AND p_wilayah IS NOT NULL AND w.wilayah = p_wilayah)
                  )
                ORDER BY w.nama ASC
            $$;
            SQL,
            <<<'SQL'
            CREATE OR REPLACE FUNCTION mobile_wilayah_kelurahan(
                p_kecamatan_id BIGINT
            )
            RETURNS TABLE (
                id BIGINT,
                nama TEXT,
                tipe TEXT,
                parent_id BIGINT,
                wilayah TEXT
            )
            LANGUAGE sql
            STABLE
            SECURITY INVOKER
            SET search_path = public
            AS $$
                SELECT
                    w.id,
                    w.nama,
                    w.tipe,
                    w.parent_id,
                    w.wilayah
                FROM wilayah_administrasi AS w
                WHERE w.parent_id = p_kecamatan_id
                  AND w.tipe IN ('kelurahan', 'desa')
                ORDER BY w.tipe ASC, w.nama ASC
            $$;
            SQL,
            <<<'SQL'
            CREATE OR REPLACE FUNCTION mobile_wilayah_feature(
                p_id BIGINT,
                p_zoom INTEGER DEFAULT 15
            )
            RETURNS JSONB
            LANGUAGE sql
            STABLE
            SECURITY INVOKER
            SET search_path = public
            AS $$
                WITH selected_wilayah AS (
                    SELECT
                        id,
                        nama,
                        tipe,
                        parent_id,
                        wilayah,
                        source,
                        osm_id,
                        properties,
                        CASE
                            WHEN COALESCE(p_zoom, 15) >= 15 THEN geom
                            WHEN COALESCE(p_zoom, 15) >= 13 THEN ST_SimplifyPreserveTopology(geom, 0.00003)
                            WHEN COALESCE(p_zoom, 15) >= 11 THEN ST_SimplifyPreserveTopology(geom, 0.00008)
                            ELSE ST_SimplifyPreserveTopology(geom, 0.00015)
                        END AS render_geom
                    FROM wilayah_administrasi
                    WHERE id = p_id
                )
                SELECT COALESCE(
                    jsonb_build_object(
                        'type', 'FeatureCollection',
                        'features', COALESCE(
                            jsonb_agg(
                                jsonb_build_object(
                                    'type', 'Feature',
                                    'id', id,
                                    'properties', jsonb_strip_nulls(
                                        jsonb_build_object(
                                            'nama', nama,
                                            'tipe', tipe,
                                            'parent_id', parent_id,
                                            'wilayah', wilayah,
                                            'source', source,
                                            'osm_id', osm_id
                                        )
                                    ),
                                    'geometry', ST_AsGeoJSON(render_geom)::jsonb
                                )
                            ) FILTER (WHERE NOT ST_IsEmpty(render_geom)),
                            '[]'::jsonb
                        )
                    ),
                    jsonb_build_object('type', 'FeatureCollection', 'features', '[]'::jsonb)
                )
                FROM selected_wilayah
            $$;
            SQL,
            <<<'SQL'
            CREATE OR REPLACE FUNCTION mobile_roads_by_wilayah(
                p_id BIGINT,
                p_zoom INTEGER DEFAULT 15
            )
            RETURNS JSONB
            LANGUAGE plpgsql
            STABLE
            SECURITY INVOKER
            SET search_path = public
            AS $$
            DECLARE
                v_wilayah TEXT;
                v_table TEXT;
                v_simplify DOUBLE PRECISION := 0.0;
                v_highway_types TEXT[] := NULL;
                v_result JSONB;
                v_sql TEXT;
            BEGIN
                SELECT wilayah INTO v_wilayah
                FROM wilayah_administrasi
                WHERE id = p_id;

                IF v_wilayah IS NULL THEN
                    RETURN jsonb_build_object('type', 'FeatureCollection', 'features', '[]'::jsonb);
                END IF;

                v_table := CASE
                    WHEN v_wilayah = 'medan' THEN 'gis_roads_medan'
                    WHEN v_wilayah = 'deli_serdang' THEN 'gis_roads_deli_serdang'
                    ELSE NULL
                END;

                IF v_table IS NULL THEN
                    RETURN jsonb_build_object('type', 'FeatureCollection', 'features', '[]'::jsonb);
                END IF;

                IF COALESCE(p_zoom, 15) >= 15 THEN
                    v_simplify := 0.0;
                    v_highway_types := NULL;
                ELSIF COALESCE(p_zoom, 15) >= 13 THEN
                    v_simplify := 0.00006;
                    v_highway_types := ARRAY[
                        'motorway', 'motorway_link',
                        'trunk', 'trunk_link',
                        'primary', 'primary_link',
                        'secondary', 'secondary_link',
                        'tertiary', 'tertiary_link',
                        'residential', 'living_street',
                        'unclassified', 'service'
                    ];
                ELSE
                    v_simplify := 0.00015;
                    v_highway_types := ARRAY[
                        'motorway', 'motorway_link',
                        'trunk', 'trunk_link',
                        'primary', 'primary_link',
                        'secondary', 'secondary_link',
                        'tertiary', 'tertiary_link'
                    ];
                END IF;

                v_sql := format(
                    $fmt$
                    WITH selected_wilayah AS (
                        SELECT id, nama, tipe, wilayah, geom
                        FROM wilayah_administrasi
                        WHERE id = $1
                    ),
                    clipped_roads AS (
                        SELECT
                            r.id,
                            r.source_id,
                            r.name,
                            r.properties,
                            ST_Multi(
                                ST_CollectionExtract(
                                    CASE
                                        WHEN $2 > 0
                                            THEN ST_SimplifyPreserveTopology(
                                                ST_Intersection(r.geom, w.geom),
                                                $3
                                            )
                                        ELSE ST_Intersection(r.geom, w.geom)
                                    END,
                                    2
                                )
                            ) AS geom
                        FROM %I AS r
                        CROSS JOIN selected_wilayah AS w
                        WHERE r.geom && w.geom
                          AND ST_Intersects(r.geom, w.geom)
                          AND ($4 IS NULL OR COALESCE(r.properties->>'highway', '') = ANY($4))
                    )
                    SELECT jsonb_build_object(
                        'type', 'FeatureCollection',
                        'features', COALESCE(
                            jsonb_agg(
                                jsonb_build_object(
                                    'type', 'Feature',
                                    'id', id,
                                    'properties', jsonb_strip_nulls(
                                        jsonb_build_object(
                                            'source_id', source_id,
                                            'name', name,
                                            'highway', properties->>'highway'
                                        )
                                    ),
                                    'geometry', ST_AsGeoJSON(geom)::jsonb
                                )
                                ORDER BY id
                            ) FILTER (WHERE NOT ST_IsEmpty(geom)),
                            '[]'::jsonb
                        )
                    )
                    FROM clipped_roads
                    $fmt$,
                    v_table
                );

                EXECUTE v_sql
                    USING p_id, v_simplify, v_simplify, v_highway_types
                    INTO v_result;

                RETURN COALESCE(v_result, jsonb_build_object('type', 'FeatureCollection', 'features', '[]'::jsonb));
            END;
            $$;
            SQL,
            'GRANT SELECT ON TABLE wilayah_administrasi TO anon, authenticated;',
            'GRANT SELECT ON TABLE gis_roads_medan TO anon, authenticated;',
            'GRANT SELECT ON TABLE gis_roads_deli_serdang TO anon, authenticated;',
            'REVOKE ALL ON FUNCTION mobile_top_level_wilayah() FROM PUBLIC;',
            'REVOKE ALL ON FUNCTION mobile_wilayah_children(BIGINT, TEXT) FROM PUBLIC;',
            'REVOKE ALL ON FUNCTION mobile_wilayah_kecamatan(BIGINT, TEXT) FROM PUBLIC;',
            'REVOKE ALL ON FUNCTION mobile_wilayah_kelurahan(BIGINT) FROM PUBLIC;',
            'REVOKE ALL ON FUNCTION mobile_wilayah_feature(BIGINT, INTEGER) FROM PUBLIC;',
            'REVOKE ALL ON FUNCTION mobile_roads_by_wilayah(BIGINT, INTEGER) FROM PUBLIC;',
            'GRANT EXECUTE ON FUNCTION mobile_top_level_wilayah() TO anon, authenticated;',
            'GRANT EXECUTE ON FUNCTION mobile_wilayah_children(BIGINT, TEXT) TO anon, authenticated;',
            'GRANT EXECUTE ON FUNCTION mobile_wilayah_kecamatan(BIGINT, TEXT) TO anon, authenticated;',
            'GRANT EXECUTE ON FUNCTION mobile_wilayah_kelurahan(BIGINT) TO anon, authenticated;',
            'GRANT EXECUTE ON FUNCTION mobile_wilayah_feature(BIGINT, INTEGER) TO anon, authenticated;',
            'GRANT EXECUTE ON FUNCTION mobile_roads_by_wilayah(BIGINT, INTEGER) TO anon, authenticated;',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $statements = [
            'DROP FUNCTION IF EXISTS mobile_roads_by_wilayah(BIGINT, INTEGER);',
            'DROP FUNCTION IF EXISTS mobile_wilayah_feature(BIGINT, INTEGER);',
            'DROP FUNCTION IF EXISTS mobile_wilayah_kelurahan(BIGINT);',
            'DROP FUNCTION IF EXISTS mobile_wilayah_kecamatan(BIGINT, TEXT);',
            'DROP FUNCTION IF EXISTS mobile_wilayah_children(BIGINT, TEXT);',
            'DROP FUNCTION IF EXISTS mobile_top_level_wilayah();',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }
}
