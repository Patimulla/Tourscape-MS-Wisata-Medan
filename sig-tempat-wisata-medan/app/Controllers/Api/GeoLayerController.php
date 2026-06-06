<?php

namespace App\Controllers\Api;

use App\Controllers\BaseController;
use App\Models\BaseGeoFeatureModel;
use App\Models\BaseRoadViewportModel;
use App\Models\BoundaryDeliSerdangModel;
use App\Models\BoundaryMedanModel;
use App\Models\RoadDeliSerdangModel;
use App\Models\RoadMedanModel;
use CodeIgniter\HTTP\ResponseInterface;

class GeoLayerController extends BaseController
{
    public function roadsMedan(): ResponseInterface
    {
        return $this->respondRoadGeoJson(new RoadMedanModel());
    }

    public function roadsDeliSerdang(): ResponseInterface
    {
        return $this->respondRoadGeoJson(new RoadDeliSerdangModel());
    }

    public function boundariesMedan(): ResponseInterface
    {
        return $this->respondGeoJson(new BoundaryMedanModel());
    }

    public function boundariesDeliSerdang(): ResponseInterface
    {
        return $this->respondGeoJson(new BoundaryDeliSerdangModel());
    }

    private function respondGeoJson(BaseGeoFeatureModel $model): ResponseInterface
    {
        @set_time_limit(300);

        return $this->response
            ->setJSON($model->getFeatureCollection())
            ->setContentType('application/geo+json');
    }

    private function respondRoadGeoJson(BaseRoadViewportModel $model): ResponseInterface
    {
        $bbox = $this->extractViewportParams();
        if ($bbox === null) {
            return $this->response
                ->setStatusCode(422)
                ->setJSON([
                    'status' => false,
                    'message' => 'Parameter viewport tidak valid. Gunakan minLng, minLat, maxLng, maxLat, dan zoom.',
                ]);
        }

        @set_time_limit(120);

        return $this->response
            ->setJSON($model->getFeatureCollectionForViewport($bbox, (int) $bbox['zoom']))
            ->setContentType('application/geo+json');
    }

    /**
     * @return array{minLng: float, minLat: float, maxLng: float, maxLat: float, zoom: int}|null
     */
    private function extractViewportParams(): ?array
    {
        $minLng = $this->request->getGet('minLng');
        $minLat = $this->request->getGet('minLat');
        $maxLng = $this->request->getGet('maxLng');
        $maxLat = $this->request->getGet('maxLat');
        $zoom = $this->request->getGet('zoom');

        if (!is_numeric($minLng) || !is_numeric($minLat) || !is_numeric($maxLng) || !is_numeric($maxLat) || !is_numeric($zoom)) {
            return null;
        }

        $bbox = [
            'minLng' => (float) $minLng,
            'minLat' => (float) $minLat,
            'maxLng' => (float) $maxLng,
            'maxLat' => (float) $maxLat,
            'zoom' => (int) round((float) $zoom),
        ];

        if (
            $bbox['minLng'] < -180 || $bbox['maxLng'] > 180 ||
            $bbox['minLat'] < -90 || $bbox['maxLat'] > 90 ||
            $bbox['minLng'] >= $bbox['maxLng'] ||
            $bbox['minLat'] >= $bbox['maxLat']
        ) {
            return null;
        }

        return $bbox;
    }
}
