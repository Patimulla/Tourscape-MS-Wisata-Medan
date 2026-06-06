<?php

namespace App\Commands;

use App\Libraries\GeoJsonLayerImporter;
use CodeIgniter\CLI\BaseCommand;
use CodeIgniter\CLI\CLI;

class ImportKecamatanLayers extends BaseCommand
{
    protected $group = 'GIS';
    protected $name = 'geo:import-kecamatan';
    protected $description = 'Import GeoJSON polygon kecamatan Medan dan Deli Serdang ke tabel PostGIS.';
    protected $usage = 'geo:import-kecamatan [options]';
    protected $options = [
        '--medan' => 'Path GeoJSON polygon kecamatan Kota Medan.',
        '--deli-serdang' => 'Path GeoJSON polygon kecamatan Kabupaten Deli Serdang.',
        '--no-truncate' => 'Jangan kosongkan tabel sebelum impor.',
    ];

    public function run(array $params)
    {
        @ini_set('memory_limit', '1024M');
        @set_time_limit(0);

        $medanPath = CLI::getOption('medan') ?: 'd:\Downloads\polygon kecamatan medan.geojson';
        $deliSerdangPath = CLI::getOption('deli-serdang') ?: 'd:\Downloads\polygon kecamatan deli serdang.geojson';
        $truncate = CLI::getOption('no-truncate') === null;

        $importer = new GeoJsonLayerImporter();

        CLI::write('Memulai impor polygon kecamatan...', 'yellow');

        $statsMedan = $importer->importKecamatanLayer($medanPath, 'medan', $truncate);
        $this->renderStats($statsMedan);

        $statsDeliSerdang = $importer->importKecamatanLayer($deliSerdangPath, 'deli_serdang', false);
        $this->renderStats($statsDeliSerdang);

        CLI::newLine();
        CLI::write('Impor kecamatan selesai.', 'green');
    }

    private function renderStats(array $stats): void
    {
        CLI::write("Import {$stats['wilayah']}", 'cyan');
        CLI::write("  File              : {$stats['file']}");
        CLI::write("  Total feature     : {$stats['total_features']}");
        CLI::write("  Berhasil diimpor  : {$stats['imported_features']}", 'green');
        CLI::write("  Dilewati          : {$stats['skipped_features']}", $stats['skipped_features'] > 0 ? 'yellow' : 'green');

        if ($stats['skipped_geometry_types'] !== []) {
            CLI::write('  Geometry dilewati : ' . json_encode($stats['skipped_geometry_types']), 'yellow');
        }
    }
}
