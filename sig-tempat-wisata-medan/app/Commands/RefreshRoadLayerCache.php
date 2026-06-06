<?php

namespace App\Commands;

use App\Libraries\RoadLayerCacheBuilder;
use CodeIgniter\CLI\BaseCommand;
use CodeIgniter\CLI\CLI;

class RefreshRoadLayerCache extends BaseCommand
{
    protected $group = 'GIS';
    protected $name = 'geo:refresh-road-cache';
    protected $description = 'Membangun ulang cache geometry jalan yang sudah disederhanakan untuk Web/Flutter.';

    public function run(array $params)
    {
        @ini_set('memory_limit', '1024M');
        @set_time_limit(0);

        $builder = new RoadLayerCacheBuilder();
        $results = $builder->rebuildAll();

        foreach ($results as $result) {
            CLI::write("Source : {$result['source_table']}", 'cyan');
            CLI::write("Cache  : {$result['cache_table']}");
            CLI::write("Rows   : {$result['cache_rows']}", 'green');
            CLI::write("Geom   : {$result['geom_type']}");
            CLI::write("SRID   : {$result['srid']}");
            CLI::newLine();
        }
    }
}
