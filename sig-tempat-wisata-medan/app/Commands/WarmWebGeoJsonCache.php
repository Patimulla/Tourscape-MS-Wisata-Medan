<?php

namespace App\Commands;

use App\Services\WebGeoJsonWarmCacheService;
use CodeIgniter\CLI\BaseCommand;
use CodeIgniter\CLI\CLI;
use Throwable;

class WarmWebGeoJsonCache extends BaseCommand
{
    protected $group = 'Geo';
    protected $name = 'geo:warm-web-cache';
    protected $description = 'Pre-warm cache GeoJSON web untuk polygon wilayah, koleksi kecamatan, dan opsional jalan compact.';
    protected $usage = 'geo:warm-web-cache [options]';
    protected $options = [
        '--roads' => 'Ikut warm cache jalan compact untuk kecamatan/leaf terpilih.',
        '--include-leaf' => 'Ikut warm polygon kelurahan/desa. Default hanya root + kecamatan.',
        '--wilayah-ids' => 'Daftar id wilayah yang diprioritaskan, pisahkan dengan koma.',
        '--polygon-zooms' => 'Daftar zoom bucket polygon, misalnya 11,13,15.',
        '--roads-zoom' => 'Zoom bucket untuk roads compact. Default: 13.',
    ];

    public function run(array $params)
    {
        @ini_set('memory_limit', '1024M');
        @set_time_limit(0);

        $service = new WebGeoJsonWarmCacheService();

        $polygonZooms = $this->parseIntegerList(CLI::getOption('polygon-zooms')) ?: [11, 13, 15];
        $roadsZoom = (int) (CLI::getOption('roads-zoom') ?: 13);
        $targetWilayahIds = $this->parseIntegerList(CLI::getOption('wilayah-ids'));
        $includeRoads = CLI::getOption('roads') !== null;
        $includeLeaf = CLI::getOption('include-leaf') !== null;

        CLI::write('Memulai warm cache GeoJSON web...', 'yellow');
        CLI::write('  Polygon zoom buckets : ' . implode(', ', $polygonZooms));
        CLI::write('  Roads warm           : ' . ($includeRoads ? 'ya' : 'tidak'));
        CLI::write('  Include leaf         : ' . ($includeLeaf ? 'ya' : 'tidak'));
        CLI::write('  Target wilayah ids   : ' . ($targetWilayahIds === [] ? 'semua default' : implode(', ', $targetWilayahIds)));
        CLI::newLine();

        try {
            $result = $service->warm([
                'polygon_zoom_buckets' => $polygonZooms,
                'roads_zoom_bucket' => $roadsZoom,
                'include_roads' => $includeRoads,
                'include_leaf' => $includeLeaf,
                'target_wilayah_ids' => $targetWilayahIds,
            ]);
        } catch (Throwable $e) {
            CLI::error($e->getMessage());
            return EXIT_ERROR;
        }

        CLI::write('Warm cache selesai.', 'green');
        CLI::write("  Polygon entries   : {$result['warmed_polygon_entries']}", 'cyan');
        CLI::write("  Collection entries: {$result['warmed_collection_entries']}", 'cyan');
        CLI::write("  Road entries      : {$result['warmed_road_entries']}", 'cyan');

        if (!empty($result['errors'])) {
            CLI::newLine();
            CLI::write('Beberapa target gagal di-warm:', 'yellow');
            foreach ($result['errors'] as $error) {
                CLI::write("  - {$error}", 'light_red');
            }
        }

        return EXIT_SUCCESS;
    }

    /**
     * @return list<int>
     */
    private function parseIntegerList(?string $raw): array
    {
        if ($raw === null || trim($raw) === '') {
            return [];
        }

        $items = array_map(
            static fn(string $item): string => trim($item),
            explode(',', $raw)
        );

        $values = [];
        foreach ($items as $item) {
            if ($item !== '' && ctype_digit($item)) {
                $values[] = (int) $item;
            }
        }

        return array_values(array_unique($values));
    }
}
