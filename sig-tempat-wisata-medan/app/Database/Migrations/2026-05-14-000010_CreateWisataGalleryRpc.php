<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateWisataGalleryRpc extends Migration
{
    public function up()
    {
        $statements = [
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
                inserted_count INTEGER := 0;
            BEGIN
                IF p_wisata_id IS NULL OR p_wisata_id <= 0 THEN
                    RAISE EXCEPTION 'p_wisata_id tidak valid';
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
            'GRANT EXECUTE ON FUNCTION insert_wisata_gallery(INTEGER, JSONB) TO anon, authenticated;',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $this->db->query('DROP FUNCTION IF EXISTS insert_wisata_gallery(INTEGER, JSONB);');
    }
}
