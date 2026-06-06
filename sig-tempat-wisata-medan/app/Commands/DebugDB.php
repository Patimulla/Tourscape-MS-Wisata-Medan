<?php
namespace App\Commands;
use CodeIgniter\CLI\BaseCommand;
use CodeIgniter\CLI\CLI;

class DebugDB extends BaseCommand
{
    protected $group       = 'Custom';
    protected $name        = 'debug:db';
    protected $description = 'Debug DB tables';

    public function run(array $params)
    {
        $db = \Config\Database::connect();
        $tables = $db->listTables();
        CLI::write("Tables: " . implode(', ', $tables));
        
        foreach(['wisata'] as $t) {
            if (in_array($t, $tables)) {
                CLI::write("Table $t:");
                $query = $db->query("SELECT id, nama_tempat, status, rating FROM $t LIMIT 10");
                print_r($query->getResultArray());
            }
        }
    }
}
