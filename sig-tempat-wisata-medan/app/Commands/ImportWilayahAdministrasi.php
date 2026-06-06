<?php

namespace App\Commands;

use App\Libraries\WilayahAdministrasiImporter;
use CodeIgniter\CLI\BaseCommand;
use CodeIgniter\CLI\CLI;
use Throwable;

class ImportWilayahAdministrasi extends BaseCommand
{
    protected $group = 'Geo';
    protected $name = 'geo:import-wilayah-administrasi';
    protected $description = 'Import kelurahan Medan dan desa/kelurahan Deli Serdang ke wilayah_administrasi.';
    protected $usage = 'geo:import-wilayah-administrasi [options]';
    protected $options = [
        '--medan-kelurahan' => 'Path GeoJSON polygon kelurahan Kota Medan.',
        '--deli-leaf' => 'Path GeoJSON polygon desa/kelurahan Kabupaten Deli Serdang.',
    ];

    public function run(array $params)
    {
        $medanPath = CLI::getOption('medan-kelurahan') ?: 'd:\Downloads\polygon kelurahan medan.geojson';
        $deliLeafPath = CLI::getOption('deli-leaf') ?: 'd:\Downloads\polygon kelurahan deli serdang.geojson';

        $importer = new WilayahAdministrasiImporter();

        CLI::write('Memulai impor wilayah administrasi level kelurahan/desa...', 'yellow');

        try {
            $medanStats = $importer->importLeafLayer($medanPath, 'medan', 'osm', 'kelurahan');
            $deliStats = $importer->importLeafLayer($deliLeafPath, 'deli_serdang', 'gadm');
        } catch (Throwable $e) {
            CLI::error($e->getMessage());
            return EXIT_ERROR;
        }

        $this->writeStats('Kelurahan Medan', $medanStats);
        $this->writeStats('Desa/Kelurahan Deli Serdang', $deliStats);
        CLI::write('Impor wilayah administrasi selesai.', 'green');

        return EXIT_SUCCESS;
    }

    private function writeStats(string $label, array $stats): void
    {
        CLI::write($label, 'cyan');
        CLI::write("  File: {$stats['file']}");
        CLI::write("  Total features: {$stats['total_features']}");
        CLI::write("  Prepared polygon features: {$stats['prepared_features']}");
        CLI::write("  Inserted rows: {$stats['inserted_features']}");
        CLI::write("  Skipped features: {$stats['skipped_features']}");
        CLI::write("  Unresolved parent rows: {$stats['unresolved_parent_rows']}");

        if (!empty($stats['skipped_geometry_types'])) {
            foreach ($stats['skipped_geometry_types'] as $type => $count) {
                CLI::write("    - {$type}: {$count}");
            }
        }
    }
}
