<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class AddWisataSubmissionOwnershipAndRevisionFlow extends Migration
{
    public function up()
    {
        $statements = [
            <<<'SQL'
            ALTER TABLE public.wisata
            ADD COLUMN IF NOT EXISTS submitter_user_id UUID NULL,
            ADD COLUMN IF NOT EXISTS catatan_admin TEXT NULL,
            ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP NULL;
            SQL,
            'CREATE INDEX IF NOT EXISTS idx_wisata_submitter_user_id ON public.wisata (submitter_user_id);',
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
                    status,
                    submitter_user_id,
                    catatan_admin,
                    reviewed_at
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
                    'pending',
                    request_uid,
                    NULL,
                    NULL
                )
                RETURNING id INTO new_id;

                RETURN new_id;
            END;
            $$;
            SQL,
            <<<'SQL'
            CREATE OR REPLACE FUNCTION update_wisata_submission(
                p_id INTEGER,
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
                p_wifi BOOLEAN DEFAULT FALSE,
                p_gallery_urls JSONB DEFAULT '[]'::jsonb
            )
            RETURNS INTEGER
            LANGUAGE plpgsql
            SECURITY DEFINER
            SET search_path = public
            AS $$
            DECLARE
                request_uid UUID := auth.uid();
                affected_rows INTEGER := 0;
            BEGIN
                IF request_uid IS NULL THEN
                    RAISE EXCEPTION 'Autentikasi dibutuhkan untuk update_wisata_submission';
                END IF;

                IF p_id IS NULL OR p_id <= 0 THEN
                    RAISE EXCEPTION 'ID pengajuan tidak valid';
                END IF;

                UPDATE wisata
                SET
                    nama_tempat = p_nama_tempat,
                    deskripsi = p_deskripsi,
                    alamat = p_alamat,
                    kecamatan = p_kecamatan,
                    kelurahan = p_kelurahan,
                    kategori = p_kategori,
                    target_pengunjung = p_target_pengunjung,
                    jam_buka = p_jam_buka,
                    jam_tutup = p_jam_tutup,
                    hari_operasional = p_hari_operasional,
                    harga_tiket = p_harga_tiket,
                    no_telepon = p_no_telepon,
                    foto = p_foto,
                    rating = p_rating,
                    toilet = p_toilet,
                    parkir = p_parkir,
                    area_bermain = p_area_bermain,
                    tempat_makan = p_tempat_makan,
                    mushola = p_mushola,
                    wifi = p_wifi,
                    geom = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326),
                    status = 'pending',
                    catatan_admin = NULL,
                    reviewed_at = NULL
                WHERE id = p_id
                  AND submitter_user_id = request_uid
                  AND status IN ('pending', 'rejected');

                GET DIAGNOSTICS affected_rows = ROW_COUNT;

                IF affected_rows = 0 THEN
                    RAISE EXCEPTION 'Pengajuan tidak ditemukan atau tidak bisa diedit';
                END IF;

                DELETE FROM wisata_foto WHERE wisata_id = p_id;

                IF p_gallery_urls IS NOT NULL AND jsonb_typeof(p_gallery_urls) = 'array' THEN
                    INSERT INTO wisata_foto (wisata_id, foto_url)
                    SELECT
                        p_id,
                        trimmed_url
                    FROM (
                        SELECT NULLIF(BTRIM(value), '') AS trimmed_url
                        FROM jsonb_array_elements_text(p_gallery_urls) AS value
                    ) AS urls
                    WHERE trimmed_url IS NOT NULL;
                END IF;

                RETURN p_id;
            END;
            $$;
            SQL,
            'REVOKE ALL ON FUNCTION update_wisata_submission(INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TIME, TIME, NUMERIC, TEXT, TEXT, NUMERIC, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, JSONB) FROM PUBLIC;',
            'GRANT EXECUTE ON FUNCTION update_wisata_submission(INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TIME, TIME, NUMERIC, TEXT, TEXT, NUMERIC, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, JSONB) TO authenticated;',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $statements = [
            'DROP FUNCTION IF EXISTS update_wisata_submission(INTEGER, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TIME, TIME, NUMERIC, TEXT, TEXT, NUMERIC, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, JSONB);',
            'DROP INDEX IF EXISTS idx_wisata_submitter_user_id;',
            'ALTER TABLE public.wisata DROP COLUMN IF EXISTS reviewed_at;',
            'ALTER TABLE public.wisata DROP COLUMN IF EXISTS catatan_admin;',
            'ALTER TABLE public.wisata DROP COLUMN IF EXISTS submitter_user_id;',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }
}
