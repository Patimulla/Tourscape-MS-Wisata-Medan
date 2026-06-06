<?php
$content = <<<'HTML'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Portal admin web untuk validasi, pengelolaan, dan pemantauan data wisata Medan dan Deli Serdang.">
    <title>Admin Portal - Tourscape MS</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
    <link rel="stylesheet" href="/css/terra-medan.css?v=4.0">
    <link rel="stylesheet" href="/css/admin.css?v=4.0">
    <link rel="stylesheet" href="/css/stitch-pages.css?v=4.0">
</head>
<body class="admin-page-body">
    <script>
        (function() {
            const saved = localStorage.getItem('terra-dark-mode');
            if (saved === 'true') {
                document.body.classList.add('dark');
            }
        })();
    </script>
HTML;

$lines = file('app/Views/admin_panel.php');
// lines to keep: from line 12 (<empty line before <?= view... >) onwards
$rest = implode("", array_slice($lines, 11));
file_put_contents('app/Views/admin_panel.php', $content . "\n" . $rest);
echo "Fixed admin_panel.php\n";
