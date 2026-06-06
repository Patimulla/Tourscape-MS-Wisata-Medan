<?php

namespace App\Commands;

use App\Libraries\GeoJsonLayerImporter;
use App\Libraries\RoadLayerCacheBuilder;
use CodeIgniter\CLI\BaseCommand;
use CodeIgniter\CLI\CLI;

class ImportGeoLayers extends BaseCommand
{
    protected $group = 'GIS';
    protected $name = 'geo:import-layers';
    protected $description = 'Import GeoJSON jalan dan batas wilayah ke tabel PostGIS.';
    protected $usage = 'geo:import-layers [options]';
    protected $options = [
        '--roads-medan' => 'Path GeoJSON jalan Kota Medan.',
        '--roads-deli-serdang' => 'Path GeoJSON jalan Kabupaten Deli Serdang.',
        '--boundary-medan' => 'Path GeoJSON polygon Kota Medan.',
        '--boundary-deli-serdang' => 'Path GeoJSON polygon Kabupaten Deli Serdang.',
        '--no-truncate' => 'Jangan kosongkan tabel sebelum impor.',
    ];

    public function run(array $params)
    {
        @ini_set('memory_limit', '1024M');
        @set_time_limit(0);

        $paths = [
            'gis_roads_medan' => CLI::getOption('roads-medan') ?: 'd:\Downloads\jalan kota medan.geojson',
            'gis_roads_deli_serdang' => CLI::getOption('roads-deli-serdang') ?: 'd:\Downloads\jalan deli serdang.geojson',
            'gis_boundaries_medan' => CLI::getOption('boundary-medan') ?: 'd:\Downloads\polygon kota medan.geojson',
            'gis_boundaries_deli_serdang' => CLI::getOption('boundary-deli-serdang') ?: 'd:\Downloads\polygon deli serdang.geojson',
        ];
        $truncate = CLI::getOption('no-truncate') === null;

        $importer = new GeoJsonLayerImporter();

        CLI::write('Memulai impor GeoJSON ke PostGIS...', 'yellow');

        foreach ($paths as $table => $path) {
            CLI::write("Import {$table}", 'cyan');
            $stats = $importer->importLayer($table, $path, $truncate);

            CLI::write("  File              : {$stats['file']}");
            CLI::write("  Total feature     : {$stats['total_features']}");
            CLI::write("  Berhasil diimpor  : {$stats['imported_features']}", 'green');
            CLI::write("  Dilewati          : {$stats['skipped_features']}", $stats['skipped_features'] > 0 ? 'yellow' : 'green');

            if ($stats['skipped_geometry_types'] !== []) {
                CLI::write('  Geometry dilewati : ' . json_encode($stats['skipped_geometry_types']), 'yellow');
            }
        }

        CLI::newLine();
        CLI::write('Membangun cache jalan untuk Web/Flutter...', 'yellow');

        $cacheBuilder = new RoadLayerCacheBuilder();
        foreach ($cacheBuilder->rebuildAll() as $result) {
            CLI::write("  {$result['cache_table']} -> {$result['geom_type']} (SRID {$result['srid']})", 'green');
        }

        CLI::newLine();
        CLI::write('Impor GeoJSON selesai.', 'green');
    }
}
