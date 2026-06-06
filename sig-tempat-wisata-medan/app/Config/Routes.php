<?php

use CodeIgniter\Router\RouteCollection;

/**
 * @var RouteCollection $routes
 */

// ============================================================
// Halaman Web
// ============================================================
$routes->get('/', 'Home::splash');                      // Landing / splash page
$routes->get('/peta', 'Home::index');                   // Alias Web GIS
$routes->get('/explore', 'Home::landing');              // Beranda publik (stats + destinasi)
$routes->get('/about', 'Home::about');                  // Halaman About
$routes->get('/wisata/detail/(:num)', 'Home::detail/$1'); // Detail lokasi publik
$routes->get('/_health', 'DeployController::health');   // Health check Railway
$routes->get('/_diagnose', 'DeployController::diagnose'); // Diagnose deploy/db/assets

$routes->get('/admin/login', 'AuthController::login');
$routes->post('/admin/attempt-login', 'AuthController::attemptLogin');
$routes->get('/admin/logout', 'AuthController::logout');

$routes->group('admin', ['filter' => 'adminauth'], static function ($routes) {
    $routes->get('/', 'AdminPanelController::index');                 // Dashboard Admin
    $routes->get('dashboard', 'AdminPanelController::index');       // Alias Dashboard
    $routes->get('kelola-lokasi', 'AdminPanelController::manage');  // Manage Locations
});

// ============================================================
// REST API
// ============================================================
$routes->group('api', function ($routes) {
    // Kategori (dari DISTINCT kolom wisata.kategori)
    $routes->get('kategori', 'Api\KategoriController::index');

    // GeoJSON layers dari PostGIS
    $routes->get('roads/medan', 'Api\GeoLayerController::roadsMedan');
    $routes->get('roads/deli-serdang', 'Api\GeoLayerController::roadsDeliSerdang');
    $routes->get('roads/by-kecamatan/(:num)', 'Api\KecamatanController::roads/$1');
    $routes->get('roads/by-wilayah/(:num)', 'Api\WilayahController::roads/$1');
    $routes->get('boundaries/medan', 'Api\GeoLayerController::boundariesMedan');
    $routes->get('boundaries/deli-serdang', 'Api\GeoLayerController::boundariesDeliSerdang');
    $routes->get('kecamatan', 'Api\KecamatanController::index');
    $routes->get('kecamatan/geojson', 'Api\KecamatanController::geojson');
    $routes->get('kecamatan/(:num)', 'Api\KecamatanController::show/$1');
    $routes->get('wilayah', 'Api\WilayahController::index');
    $routes->get('wilayah/kecamatan', 'Api\WilayahController::kecamatan');
    $routes->get('wilayah/kelurahan', 'Api\WilayahController::kelurahan');
    $routes->get('wilayah/resolve', 'Api\WilayahController::resolve');
    $routes->get('wilayah/children/(:num)', 'Api\WilayahController::children/$1');
    $routes->get('wilayah/children-geojson/(:num)', 'Api\WilayahController::childrenGeoJson/$1');
    $routes->get('wilayah/(:num)', 'Api\WilayahController::show/$1');

    // Wisata CRUD
    $routes->get('wisata', 'Api\WisataController::index');
    $routes->get('wisata/nearby', 'Api\WisataController::nearby');
    $routes->get('wisata/(:num)', 'Api\WisataController::show/$1');
    $routes->post('wisata', 'Api\WisataController::create');
    $routes->put('wisata/(:num)', 'Api\WisataController::update/$1');
    $routes->delete('wisata/(:num)', 'Api\WisataController::delete/$1');

    // Upload foto ke Supabase
    $routes->post('upload', 'Api\UploadController::foto');

    // Admin
    $routes->get('admin/wisata/pending', 'Api\AdminController::pending');
    $routes->get('admin/mobile-users', 'Api\AdminController::mobileUsers');
    $routes->get('admin/wisata/(:num)', 'Api\AdminController::detail/$1');
    $routes->put('admin/wisata/(:num)/approve', 'Api\AdminController::approve/$1');
    $routes->put('admin/wisata/(:num)/reject', 'Api\AdminController::reject/$1');
    $routes->post('admin/migrate-foto-table', 'Api\AdminController::migrateFotoTable');
});
