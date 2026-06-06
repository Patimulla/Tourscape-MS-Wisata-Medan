<?php

namespace App\Models;

class RoadMedanModel extends BaseRoadViewportModel
{
    protected $table = 'gis_roads_medan';
    protected $allowedFields = ['source_id', 'name', 'properties', 'geom'];
}
