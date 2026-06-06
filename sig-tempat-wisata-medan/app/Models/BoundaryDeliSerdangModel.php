<?php

namespace App\Models;

class BoundaryDeliSerdangModel extends BaseGeoFeatureModel
{
    protected $table = 'gis_boundaries_deli_serdang';
    protected $allowedFields = ['source_id', 'name', 'properties', 'geom'];
}
