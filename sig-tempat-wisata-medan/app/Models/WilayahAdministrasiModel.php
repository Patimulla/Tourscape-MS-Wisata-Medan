<?php

namespace App\Models;

class WilayahAdministrasiModel extends BaseGeoFeatureModel
{
    protected $table = 'wilayah_administrasi';
    protected $allowedFields = [
        'parent_id',
        'nama',
        'tipe',
        'wilayah',
        'source',
        'osm_id',
        'properties',
        'geom',
        'created_at',
        'updated_at',
    ];

    /**
     * @param list<string> $kategori
     * @return array{data: list<array<string, mixed>>, pagination: array<string, int>}
     */
    public function getSummaryList(
        array $kategori = [],
        ?int $parentId = null,
        ?string $wilayah = null,
        ?string $search = null,
        int $page = 1,
        int $perPage = 100
    ): array {
        $page = max(1, $page);
        $perPage = min(200, max(1, $perPage));

        $builder = $this->db->table($this->table)
            ->select('id, nama, tipe, parent_id, wilayah');

        if ($kategori !== []) {
            $builder->whereIn('tipe', $kategori);
        }

        if ($parentId !== null) {
            $builder->where('parent_id', $parentId);
        }

        if ($wilayah !== null && $wilayah !== '') {
            $builder->where('wilayah', $wilayah);
        }

        if ($search !== null && $search !== '') {
            $escapedSearch = str_replace("'", "''", mb_strtolower($search));
            $builder->where("LOWER(nama) LIKE '%{$escapedSearch}%'", null, false);
        }

        $countBuilder = clone $builder;
        $total = (int) $countBuilder->countAllResults();

        $rows = $builder
            ->orderBy('wilayah', 'ASC')
            ->orderBy('tipe', 'ASC')
            ->orderBy('nama', 'ASC')
            ->limit($perPage, ($page - 1) * $perPage)
            ->get()
            ->getResultArray();

        return [
            'data' => $rows,
            'pagination' => [
                'page' => $page,
                'per_page' => $perPage,
                'total' => $total,
                'total_pages' => (int) ceil($total / $perPage),
            ],
        ];
    }

    /**
     * @param list<string> $kategori
     * @return list<array<string, mixed>>
     */
    public function getChildrenSummary(int $parentId, array $kategori = []): array
    {
        $builder = $this->select('id, nama, tipe, parent_id, wilayah')
            ->where('parent_id', $parentId);

        if ($kategori !== []) {
            $builder->whereIn('tipe', $kategori);
        }

        return $builder
            ->orderBy('tipe', 'ASC')
            ->orderBy('nama', 'ASC')
            ->findAll();
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function getKecamatanSummary(?int $wilayahId = null, ?string $wilayah = null): array
    {
        $builder = $this->select('id, nama, tipe, parent_id, wilayah')
            ->where('tipe', 'kecamatan');

        if ($wilayahId !== null) {
            $builder->where('parent_id', $wilayahId);
        } elseif ($wilayah !== null && $wilayah !== '') {
            $builder->where('wilayah', $wilayah);
        }

        return $builder
            ->orderBy('nama', 'ASC')
            ->findAll();
    }

    /**
     * @return list<array<string, mixed>>
     */
    public function getLeafSummary(int $kecamatanId): array
    {
        return $this->select('id, nama, tipe, parent_id, wilayah')
            ->where('parent_id', $kecamatanId)
            ->whereIn('tipe', ['kelurahan', 'desa'])
            ->orderBy('tipe', 'ASC')
            ->orderBy('nama', 'ASC')
            ->findAll();
    }

    /**
     * @return array<string, mixed>|null
     */
    public function resolveHierarchyByPoint(float $latitude, float $longitude): ?array
    {
        $pointWkt = sprintf('POINT(%F %F)', $longitude, $latitude);

        $sql = <<<SQL
            WITH matched_leaf AS (
                SELECT
                    leaf.id,
                    leaf.nama,
                    leaf.tipe,
                    leaf.parent_id,
                    leaf.wilayah
                FROM {$this->table} AS leaf
                WHERE leaf.tipe IN ('kelurahan', 'desa')
                  AND ST_Contains(leaf.geom, ST_GeomFromText(?, 4326))
                ORDER BY leaf.id ASC
                LIMIT 1
            ),
            matched_kecamatan AS (
                SELECT
                    kec.id,
                    kec.nama,
                    kec.tipe,
                    kec.parent_id,
                    kec.wilayah
                FROM {$this->table} AS kec
                WHERE kec.tipe = 'kecamatan'
                  AND ST_Contains(kec.geom, ST_GeomFromText(?, 4326))
                ORDER BY kec.id ASC
                LIMIT 1
            )
            SELECT
                kota.id AS kota_id,
                kota.nama AS kota_nama,
                kota.tipe AS kota_tipe,
                kec.id AS kecamatan_id,
                kec.nama AS kecamatan_nama,
                leaf.id AS kelurahan_id,
                leaf.nama AS kelurahan_nama,
                leaf.tipe AS kelurahan_tipe
            FROM matched_kecamatan AS kec
            LEFT JOIN matched_leaf AS leaf ON leaf.parent_id = kec.id
            LEFT JOIN {$this->table} AS kota ON kota.id = kec.parent_id
            LIMIT 1
        SQL;

        $row = $this->db->query($sql, [$pointWkt, $pointWkt])->getRowArray();

        return $row ?: null;
    }

    public function getFeatureCollectionById(int $id, int $zoom = 15): ?array
    {
        $simplifyTolerance = $this->getSimplifyTolerance($zoom);

        $sql = <<<SQL
            SELECT json_build_object(
                'type', 'FeatureCollection',
                'features', COALESCE(
                    json_agg(
                        json_build_object(
                            'type', 'Feature',
                            'id', id,
                            'properties', jsonb_strip_nulls(
                                jsonb_build_object(
                                    'nama', nama,
                                    'tipe', tipe,
                                    'parent_id', parent_id,
                                    'parent_nama', parent_nama,
                                    'parent_tipe', parent_tipe,
                                    'grandparent_id', grandparent_id,
                                    'grandparent_nama', grandparent_nama,
                                    'grandparent_tipe', grandparent_tipe,
                                    'wilayah', wilayah,
                                    'source', source,
                                    'osm_id', osm_id
                                )
                            ),
                            'geometry', ST_AsGeoJSON(
                                CASE
                                    WHEN ? > 0 THEN ST_SimplifyPreserveTopology(geom, ?)
                                    ELSE geom
                                END
                            , 6)::json
                        )
                    ),
                    '[]'::json
                )
            ) AS geojson
            FROM (
                SELECT
                    w.id,
                    w.nama,
                    w.tipe,
                    w.parent_id,
                    parent.nama AS parent_nama,
                    parent.tipe AS parent_tipe,
                    grandparent.id AS grandparent_id,
                    grandparent.nama AS grandparent_nama,
                    grandparent.tipe AS grandparent_tipe,
                    w.wilayah,
                    w.source,
                    w.osm_id,
                    w.geom
                FROM {$this->table} AS w
                LEFT JOIN {$this->table} AS parent ON parent.id = w.parent_id
                LEFT JOIN {$this->table} AS grandparent ON grandparent.id = parent.parent_id
                WHERE w.id = ?
            ) AS selected_wilayah
        SQL;

        $row = $this->db->query($sql, [$simplifyTolerance, $simplifyTolerance, $id])->getRowArray();
        $featureCollection = json_decode($row['geojson'] ?? '', true);

        if (!is_array($featureCollection) || ($featureCollection['features'] ?? []) === []) {
            return null;
        }

        return $featureCollection;
    }

    /**
     * @param list<string> $kategori
     */
    public function getFeatureCollectionByParent(int $parentId, array $kategori = [], int $zoom = 15): array
    {
        $simplifyTolerance = $this->getSimplifyTolerance($zoom);
        $binds = [$simplifyTolerance, $simplifyTolerance, $parentId];
        $kategoriCondition = '';

        if ($kategori !== []) {
            $placeholders = implode(', ', array_fill(0, count($kategori), '?'));
            $kategoriCondition = "AND w.tipe IN ({$placeholders})";
            array_push($binds, ...$kategori);
        }

        $sql = <<<SQL
            SELECT json_build_object(
                'type', 'FeatureCollection',
                'features', COALESCE(
                    json_agg(
                        json_build_object(
                            'type', 'Feature',
                            'id', id,
                            'properties', jsonb_strip_nulls(
                                jsonb_build_object(
                                    'nama', nama,
                                    'tipe', tipe,
                                    'parent_id', parent_id,
                                    'parent_nama', parent_nama,
                                    'parent_tipe', parent_tipe,
                                    'grandparent_id', grandparent_id,
                                    'grandparent_nama', grandparent_nama,
                                    'grandparent_tipe', grandparent_tipe,
                                    'wilayah', wilayah,
                                    'source', source,
                                    'osm_id', osm_id
                                )
                            ),
                            'geometry', ST_AsGeoJSON(
                                CASE
                                    WHEN ? > 0 THEN ST_SimplifyPreserveTopology(geom, ?)
                                    ELSE geom
                                END
                            , 6)::json
                        )
                        ORDER BY tipe, nama
                    ),
                    '[]'::json
                )
            ) AS geojson
            FROM (
                SELECT
                    w.id,
                    w.nama,
                    w.tipe,
                    w.parent_id,
                    parent.nama AS parent_nama,
                    parent.tipe AS parent_tipe,
                    grandparent.id AS grandparent_id,
                    grandparent.nama AS grandparent_nama,
                    grandparent.tipe AS grandparent_tipe,
                    w.wilayah,
                    w.source,
                    w.osm_id,
                    w.geom
                FROM {$this->table} AS w
                LEFT JOIN {$this->table} AS parent ON parent.id = w.parent_id
                LEFT JOIN {$this->table} AS grandparent ON grandparent.id = parent.parent_id
                WHERE w.parent_id = ?
                {$kategoriCondition}
            ) AS child_wilayah
        SQL;

        $row = $this->db->query($sql, $binds)->getRowArray();

        return json_decode($row['geojson'] ?? '{"type":"FeatureCollection","features":[]}', true) ?? [
            'type' => 'FeatureCollection',
            'features' => [],
        ];
    }

    public function normalizeZoomBucket(int $zoom): int
    {
        if ($zoom >= 15) {
            return 15;
        }

        if ($zoom >= 13) {
            return 13;
        }

        if ($zoom >= 11) {
            return 11;
        }

        return 10;
    }

    private function getSimplifyTolerance(int $zoom): float
    {
        if ($zoom >= 15) {
            return 0.0;
        }

        if ($zoom >= 13) {
            return 0.00003;
        }

        if ($zoom >= 11) {
            return 0.00008;
        }

        return 0.00015;
    }
}
