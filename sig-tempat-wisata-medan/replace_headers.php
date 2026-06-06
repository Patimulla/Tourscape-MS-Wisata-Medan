<?php
$files = [
    'app/Views/about_page.php' => 'about',
    'app/Views/wisata_detail_page.php' => 'explore',
    'app/Views/webgis.php' => 'peta',
    'app/Views/splash_page.php' => 'home'
];

foreach ($files as $file => $activePage) {
    if (!file_exists($file)) continue;
    $content = file_get_contents($file);
    
    // Find <header class="site-topbar"... to </header>
    $pattern = '/<header[^>]*class="[^"]*site-topbar[^"]*"[^>]*>.*?<\/header>/s';
    
    if (preg_match($pattern, $content, $matches)) {
        if ($file === 'app/Views/webgis.php') {
            $replacement = "<?= view('layout/navbar', ['activePage' => '$activePage', 'headerId' => 'app-header', 'headerClass' => 'webgis-topbar', 'innerClass' => 'webgis-topbar-inner']) ?>";
        } else {
            $replacement = "<?= view('layout/navbar', ['activePage' => '$activePage']) ?>";
        }
        $newContent = preg_replace($pattern, $replacement, $content);
        file_put_contents($file, $newContent);
        echo "Replaced in $file\n";
    } else {
        // Also check if admin_panel.php has <header class="admin-header">
        echo "Not found in $file\n";
    }
}

// Handle admin files
$adminFiles = ['app/Views/admin_panel.php', 'app/Views/admin_locations.php'];
foreach ($adminFiles as $file) {
    if (!file_exists($file)) continue;
    $content = file_get_contents($file);
    $pattern = '/<header[^>]*class="[^"]*admin-header[^"]*"[^>]*>.*?<\/header>/s';
    if (preg_match($pattern, $content)) {
        $replacement = "<?= view('layout/navbar', ['activePage' => 'admin']) ?>";
        $newContent = preg_replace($pattern, $replacement, $content);
        file_put_contents($file, $newContent);
        echo "Replaced in $file\n";
    }
}
