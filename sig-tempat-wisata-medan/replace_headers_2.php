<?php
$file = 'app/Views/admin_locations.php';
$content = file_get_contents($file);
$pattern = '/<header[^>]*class="[^"]*admin-extra-topbar[^"]*"[^>]*>.*?<\/header>/s';
if (preg_match($pattern, $content)) {
    $replacement = "<?= view('layout/navbar', ['activePage' => 'admin']) ?>";
    $newContent = preg_replace($pattern, $replacement, $content);
    file_put_contents($file, $newContent);
    echo "Replaced in $file\n";
} else {
    echo "Not found in $file\n";
}
