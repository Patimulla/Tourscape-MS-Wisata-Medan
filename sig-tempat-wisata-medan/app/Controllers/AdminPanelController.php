<?php

namespace App\Controllers;

class AdminPanelController extends BaseController
{
    /**
     * Halaman dashboard admin utama.
     */
    public function index(): string
    {
        return view('admin_panel');
    }

    /**
     * Halaman kelola lokasi wisata.
     */
    public function manage(): string
    {
        return view('admin_locations');
    }
}
