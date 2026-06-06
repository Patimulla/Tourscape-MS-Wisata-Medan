<?php

namespace App\Database\Migrations;

use CodeIgniter\Database\Migration;

class CreateWisataFotoTable extends Migration
{
    public function up()
    {
        $statements = [
            <<<'SQL'
            CREATE TABLE IF NOT EXISTS wisata_foto (
                id BIGSERIAL PRIMARY KEY,
                wisata_id BIGINT NOT NULL,
                foto_url VARCHAR(500) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            SQL,
            'CREATE INDEX IF NOT EXISTS idx_wisata_foto_wisata_id ON wisata_foto (wisata_id);',
            'CREATE INDEX IF NOT EXISTS idx_wisata_foto_created_at ON wisata_foto (created_at);',
            'GRANT SELECT, INSERT ON wisata_foto TO anon, authenticated;',
            'GRANT USAGE, SELECT ON SEQUENCE wisata_foto_id_seq TO anon, authenticated;',
        ];

        foreach ($statements as $statement) {
            $this->db->query($statement);
        }
    }

    public function down()
    {
        $this->db->query('DROP TABLE IF EXISTS wisata_foto;');
    }
}
