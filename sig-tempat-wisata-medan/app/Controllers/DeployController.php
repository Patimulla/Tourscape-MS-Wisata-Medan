<?php

namespace App\Controllers;

use CodeIgniter\HTTP\ResponseInterface;

class DeployController extends BaseController
{
    public function health(): ResponseInterface
    {
        return $this->response->setJSON([
            'status'      => 'ok',
            'environment' => ENVIRONMENT,
            'app'         => 'Tourscape MS Web',
            'time'        => date(DATE_ATOM),
        ]);
    }
}
