<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class AddDeleteWisataSubmissionRpc extends Migration
{
    public function up()
    {
        $statements = [
            <<<'SQL'
            CREATE OR REPLACE FUNCTION delete_wisata_submission(
                p_id INTEGER
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
                    RAISE EXCEPTION 'Autentikasi dibutuhkan untuk delete_wisata_submission';
                END IF;

                IF p_id IS NULL OR p_id <= 0 THEN
                    RAISE EXCEPTION 'ID pengajuan tidak valid';
                END IF;

                IF NOT EXISTS (
                    SELECT 1
                    FROM wisata
                    WHERE id = p_id
                      AND submitter_user_id = request_uid
                      AND status IN ('pending', 'rejected')
                ) THEN
                    RAISE EXCEPTION 'Pengajuan tidak ditemukan atau tidak bisa dibatalkan';
                END IF;

                DELETE FROM wisata_foto
                WHERE wisata_id = p_id;

                DELETE FROM wisata
                WHERE id = p_id
                  AND submitter_user_id = request_uid
                  AND status IN ('pending', 'rejected');

                GET DIAGNOSTICS affected_rows = ROW_COUNT;

                IF affected_rows = 0 THEN
                    RAISE EXCEPTION 'Pengajuan tidak ditemukan atau tidak bisa dibatalkan';
                END IF;

                RETURN p_id;
            END;
            $$;
            SQL,
            'REVOKE ALL ON FUNCTION delete_wisata_submission(INTEGER) FROM PUBLIC;',
            'GRANT EXECUTE ON FUNCTION delete_wisata_submission(INTEGER) TO authenticated;',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $this->db->query(
            'DROP FUNCTION IF EXISTS delete_wisata_submission(INTEGER);'
        );
    }
}
