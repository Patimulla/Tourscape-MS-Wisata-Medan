<?php

namespace App\Controllers;

class Home extends BaseController
{
    /**
     * Halaman utama peta publik.
     */
    public function index(): string
    {
        return view('webgis');
    }

    /**
     * Landing / splash page utama.
     */
    public function splash(): string
    {
        return view('splash_page');
    }

    /**
     * Halaman beranda publik.
     */
    public function landing(): string
    {
        return view('landing_page');
    }

    /**
     * Halaman detail lokasi wisata publik.
     */
    public function detail(int $id): string
    {
        return view('wisata_detail_page', [
            'wisataId' => $id,
        ]);
    }

    /**
     * Halaman about.
     */
    public function about(): string
    {
        $adminModel = new \App\Models\AdminMobileModel();
        $admins = $adminModel->findAll();

        return view('about_page', [
            'admins' => $admins,
        ]);
    }
}
