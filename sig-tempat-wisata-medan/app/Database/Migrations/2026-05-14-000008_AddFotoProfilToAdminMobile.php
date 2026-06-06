<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class AddFotoProfilToAdminMobile extends Migration
{
    public function up()
    {
        $this->db->query(<<<'SQL'
            ALTER TABLE public.admin_mobile
            ADD COLUMN IF NOT EXISTS foto_profil TEXT NULL;
        SQL);
    }

    public function down()
    {
        $this->db->query(<<<'SQL'
            ALTER TABLE public.admin_mobile
            DROP COLUMN IF EXISTS foto_profil;
        SQL);
    }
}
