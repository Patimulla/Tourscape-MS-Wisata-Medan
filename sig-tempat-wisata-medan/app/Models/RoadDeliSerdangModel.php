<?php

namespace App\Models;

class RoadDeliSerdangModel extends BaseRoadViewportModel
{
    protected $table = 'gis_roads_deli_serdang';
    protected $allowedFields = ['source_id', 'name', 'properties', 'geom'];
}
