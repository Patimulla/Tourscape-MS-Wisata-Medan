<?php
$response = file_get_contents('http://localhost:8080/api/kategori');
echo "Response: \n" . $response . "\n";
