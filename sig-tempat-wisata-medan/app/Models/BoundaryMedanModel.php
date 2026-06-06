<?php

namespace App\Models;

class BoundaryMedanModel extends BaseGeoFeatureModel
{
    protected $table = 'gis_boundaries_medan';
    protected $allowedFields = ['source_id', 'name', 'properties', 'geom'];
}
