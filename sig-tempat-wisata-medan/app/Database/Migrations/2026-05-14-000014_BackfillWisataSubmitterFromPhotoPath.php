<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class BackfillWisataSubmitterFromPhotoPath extends Migration
{
    public function up()
    {
        $statements = [
            <<<'SQL'
            UPDATE public.wisata AS w
            SET submitter_user_id = derived.submitter_uuid::uuid
            FROM (
                SELECT
                    id,
                    substring(
                        foto
                        FROM 'mobile-submissions/([0-9a-fA-F-]{36})/'
                    ) AS submitter_uuid
                FROM public.wisata
                WHERE submitter_user_id IS NULL
                  AND foto IS NOT NULL
                  AND foto <> ''
            ) AS derived
            WHERE w.id = derived.id
              AND derived.submitter_uuid IS NOT NULL
              AND w.submitter_user_id IS NULL;
            SQL,
            <<<'SQL'
            UPDATE public.wisata AS w
            SET submitter_user_id = gallery_match.submitter_uuid::uuid
            FROM (
                SELECT DISTINCT ON (wf.wisata_id)
                    wf.wisata_id,
                    substring(
                        wf.foto_url
                        FROM 'mobile-submissions/([0-9a-fA-F-]{36})/'
                    ) AS submitter_uuid
                FROM public.wisata_foto wf
                INNER JOIN public.wisata w2 ON w2.id = wf.wisata_id
                WHERE w2.submitter_user_id IS NULL
                  AND wf.foto_url IS NOT NULL
                  AND wf.foto_url <> ''
                ORDER BY wf.wisata_id, wf.id ASC
            ) AS gallery_match
            WHERE w.id = gallery_match.wisata_id
              AND gallery_match.submitter_uuid IS NOT NULL
              AND w.submitter_user_id IS NULL;
            SQL,
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        // No-op: backfill should not be automatically reversed.
    }
}
