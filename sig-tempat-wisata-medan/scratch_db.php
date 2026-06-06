<?php
define('FCPATH', __DIR__ . DIRECTORY_SEPARATOR . 'public' . DIRECTORY_SEPARATOR);
require FCPATH . '../app/Config/Paths.php';
$paths = new Config\Paths();
require rtrim($paths->systemDirectory, '\\/ ') . DIRECTORY_SEPARATOR . 'bootstrap.php';

$db = \Config\Database::connect();
$tables = $db->listTables();
echo "Tables:\n";
print_r($tables);

foreach(['admins', 'admin', 'users', 'mahasiswa'] as $t) {
    if (in_array($t, $tables)) {
        echo "Table $t:\n";
        $query = $db->query("SELECT * FROM $t");
        print_r($query->getResultArray());
    }
}
