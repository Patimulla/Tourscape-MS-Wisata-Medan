<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class HardenMobileSupabaseAccess extends Migration
{
    public function up()
    {
        $statements = [
            <<<'SQL'
            INSERT INTO storage.buckets (id, name, public)
            VALUES ('wisata', 'wisata', true)
            ON CONFLICT (id) DO UPDATE SET public = EXCLUDED.public;
            SQL,
            'DROP POLICY IF EXISTS "Public Select" ON storage.objects;',
            'DROP POLICY IF EXISTS "Public Update" ON storage.objects;',
            'DROP POLICY IF EXISTS "Public Delete" ON storage.objects;',
            <<<'SQL'
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_policies
                    WHERE schemaname = 'storage'
                      AND tablename = 'objects'
                      AND policyname = 'Wisata Public Read'
                ) THEN
                    CREATE POLICY "Wisata Public Read"
                    ON storage.objects
                    FOR SELECT
                    TO public
                    USING (bucket_id = 'wisata');
                END IF;
            END
            $$;
            SQL,
            <<<'SQL'
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_policies
                    WHERE schemaname = 'storage'
                      AND tablename = 'objects'
                      AND policyname = 'Wisata Auth Insert Own Folder'
                ) THEN
                    CREATE POLICY "Wisata Auth Insert Own Folder"
                    ON storage.objects
                    FOR INSERT
                    TO authenticated
                    WITH CHECK (
                        bucket_id = 'wisata'
                        AND (storage.foldername(name))[1] = 'mobile-submissions'
                        AND (storage.foldername(name))[2] = auth.uid()::text
                    );
                END IF;
            END
            $$;
            SQL,
            <<<'SQL'
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_policies
                    WHERE schemaname = 'storage'
                      AND tablename = 'objects'
                      AND policyname = 'Wisata Auth Update Own Folder'
                ) THEN
                    CREATE POLICY "Wisata Auth Update Own Folder"
                    ON storage.objects
                    FOR UPDATE
                    TO authenticated
                    USING (
                        bucket_id = 'wisata'
                        AND (storage.foldername(name))[1] = 'mobile-submissions'
                        AND (storage.foldername(name))[2] = auth.uid()::text
                    )
                    WITH CHECK (
                        bucket_id = 'wisata'
                        AND (storage.foldername(name))[1] = 'mobile-submissions'
                        AND (storage.foldername(name))[2] = auth.uid()::text
                    );
                END IF;
            END
            $$;
            SQL,
            <<<'SQL'
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_policies
                    WHERE schemaname = 'storage'
                      AND tablename = 'objects'
                      AND policyname = 'Wisata Auth Delete Own Folder'
                ) THEN
                    CREATE POLICY "Wisata Auth Delete Own Folder"
                    ON storage.objects
                    FOR DELETE
                    TO authenticated
                    USING (
                        bucket_id = 'wisata'
                        AND (storage.foldername(name))[1] = 'mobile-submissions'
                        AND (storage.foldername(name))[2] = auth.uid()::text
                    );
                END IF;
            END
            $$;
            SQL,
            <<<'SQL'
            CREATE OR REPLACE FUNCTION insert_wisata(
                p_nama_tempat TEXT,
                p_deskripsi TEXT DEFAULT '',
                p_alamat TEXT DEFAULT '',
                p_kecamatan TEXT DEFAULT '',
                p_kelurahan TEXT DEFAULT '',
                p_kategori TEXT DEFAULT '',
                p_target_pengunjung TEXT DEFAULT 'umum',
                p_jam_buka TIME DEFAULT '08:00:00',
                p_jam_tutup TIME DEFAULT '17:00:00',
                p_harga_tiket NUMERIC DEFAULT 0,
                p_no_telepon TEXT DEFAULT '',
                p_foto TEXT DEFAULT '',
                p_rating NUMERIC DEFAULT NULL,
                p_hari_operasional TEXT DEFAULT '',
                p_lat DOUBLE PRECISION DEFAULT 3.5952,
                p_lng DOUBLE PRECISION DEFAULT 98.6722,
                p_toilet BOOLEAN DEFAULT FALSE,
                p_parkir BOOLEAN DEFAULT FALSE,
                p_area_bermain BOOLEAN DEFAULT FALSE,
                p_tempat_makan BOOLEAN DEFAULT FALSE,
                p_mushola BOOLEAN DEFAULT FALSE,
                p_wifi BOOLEAN DEFAULT FALSE
            )
            RETURNS INTEGER
            LANGUAGE plpgsql
            SECURITY DEFINER
            SET search_path = public
            AS $$
            DECLARE
                request_uid UUID := auth.uid();
                new_id INTEGER;
            BEGIN
                IF request_uid IS NULL THEN
                    RAISE EXCEPTION 'Autentikasi dibutuhkan untuk insert_wisata';
                END IF;

                INSERT INTO wisata (
                    nama_tempat,
                    deskripsi,
                    alamat,
                    kecamatan,
                    kelurahan,
                    kategori,
                    target_pengunjung,
                    jam_buka,
                    jam_tutup,
                    hari_operasional,
                    harga_tiket,
                    no_telepon,
                    foto,
                    rating,
                    toilet,
                    parkir,
                    area_bermain,
                    tempat_makan,
                    mushola,
                    wifi,
                    geom,
                    status
                ) VALUES (
                    p_nama_tempat,
                    p_deskripsi,
                    p_alamat,
                    p_kecamatan,
                    p_kelurahan,
                    p_kategori,
                    p_target_pengunjung,
                    p_jam_buka,
                    p_jam_tutup,
                    p_hari_operasional,
                    p_harga_tiket,
                    p_no_telepon,
                    p_foto,
                    p_rating,
                    p_toilet,
                    p_parkir,
                    p_area_bermain,
                    p_tempat_makan,
                    p_mushola,
                    p_wifi,
                    ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326),
                    'pending'
                )
                RETURNING id INTO new_id;

                RETURN new_id;
            END;
            $$;
            SQL,
            <<<'SQL'
            REVOKE ALL ON FUNCTION insert_wisata(
                TEXT,
                TEXT,
                TEXT,
                TEXT,
                TEXT,
                TEXT,
                TEXT,
                TIME,
                TIME,
                NUMERIC,
                TEXT,
                TEXT,
                NUMERIC,
                TEXT,
                DOUBLE PRECISION,
                DOUBLE PRECISION,
                BOOLEAN,
                BOOLEAN,
                BOOLEAN,
                BOOLEAN,
                BOOLEAN,
                BOOLEAN
            ) FROM PUBLIC;
            SQL,
            <<<'SQL'
            GRANT EXECUTE ON FUNCTION insert_wisata(
                TEXT,
                TEXT,
                TEXT,
                TEXT,
                TEXT,
                TEXT,
                TEXT,
                TIME,
                TIME,
                NUMERIC,
                TEXT,
                TEXT,
                NUMERIC,
                TEXT,
                DOUBLE PRECISION,
                DOUBLE PRECISION,
                BOOLEAN,
                BOOLEAN,
                BOOLEAN,
                BOOLEAN,
                BOOLEAN,
                BOOLEAN
            ) TO authenticated;
            SQL,
            <<<'SQL'
            CREATE OR REPLACE FUNCTION insert_wisata_gallery(
                p_wisata_id INTEGER,
                p_foto_urls JSONB
            )
            RETURNS INTEGER
            LANGUAGE plpgsql
            SECURITY DEFINER
            SET search_path = public
            AS $$
            DECLARE
                request_uid UUID := auth.uid();
                inserted_count INTEGER := 0;
            BEGIN
                IF request_uid IS NULL THEN
                    RAISE EXCEPTION 'Autentikasi dibutuhkan untuk insert_wisata_gallery';
                END IF;

                IF p_wisata_id IS NULL OR p_wisata_id <= 0 THEN
                    RAISE EXCEPTION 'p_wisata_id tidak valid';
                END IF;

                IF NOT EXISTS (
                    SELECT 1
                    FROM wisata
                    WHERE id = p_wisata_id
                ) THEN
                    RAISE EXCEPTION 'Wisata tidak ditemukan';
                END IF;

                IF p_foto_urls IS NULL OR jsonb_typeof(p_foto_urls) <> 'array' THEN
                    RETURN 0;
                END IF;

                INSERT INTO wisata_foto (wisata_id, foto_url)
                SELECT
                    p_wisata_id,
                    trimmed_url
                FROM (
                    SELECT NULLIF(BTRIM(value), '') AS trimmed_url
                    FROM jsonb_array_elements_text(p_foto_urls) AS value
                ) AS urls
                WHERE trimmed_url IS NOT NULL;

                GET DIAGNOSTICS inserted_count = ROW_COUNT;
                RETURN inserted_count;
            END;
            $$;
            SQL,
            'REVOKE ALL ON FUNCTION insert_wisata_gallery(INTEGER, JSONB) FROM PUBLIC;',
            'GRANT EXECUTE ON FUNCTION insert_wisata_gallery(INTEGER, JSONB) TO authenticated;',
            'REVOKE INSERT, UPDATE, DELETE ON wisata FROM anon, authenticated;',
            'GRANT SELECT ON wisata TO anon, authenticated;',
            'REVOKE INSERT, UPDATE, DELETE ON wisata_foto FROM anon, authenticated;',
            'GRANT SELECT ON wisata_foto TO anon, authenticated;',
            'REVOKE ALL ON SEQUENCE wisata_foto_id_seq FROM anon, authenticated;',
            <<<'SQL'
            DO $$
            BEGIN
                IF to_regclass('public.review') IS NOT NULL THEN
                    GRANT SELECT ON review TO anon, authenticated;
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
            'DROP POLICY IF EXISTS "Wisata Auth Delete Own Folder" ON storage.objects;',
            'DROP POLICY IF EXISTS "Wisata Auth Update Own Folder" ON storage.objects;',
            'DROP POLICY IF EXISTS "Wisata Auth Insert Own Folder" ON storage.objects;',
            'DROP POLICY IF EXISTS "Wisata Public Read" ON storage.objects;',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }
}
