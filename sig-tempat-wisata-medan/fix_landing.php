<?php
$content = <<<HTML
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Beranda Tourscape MS untuk menjelajahi destinasi unggulan, statistik, dan akses cepat ke peta interaktif.">
    <title>Beranda - Tourscape MS</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="/css/terra-medan.css?v=3.0">
    <link rel="stylesheet" href="/css/stitch-pages.css?v=4.0">
</head>
<body class="site-page">
    <script>
        (function() {
            const saved = localStorage.getItem('terra-dark-mode');
            if (saved === 'true') {
                document.body.classList.add('dark');
            }
        })();
    </script>

    <?= view('layout/navbar', ['activePage' => 'explore']) ?>

    <main class="site-main">
        <div class="tm-shell" style="position:relative;">
            <div class="tm-orb tm-orb-teal" style="width:300px;height:300px;top:-80px;right:-60px;"></div>
            <div class="tm-orb tm-orb-emerald" style="width:200px;height:200px;bottom:200px;left:-80px;animation-delay:3s;"></div>
            <section class="hero-panel landing-hero section-shell" data-anim="fadeUp">
                <div>
                    <span class="tm-kicker">Explore Medan &amp; Deli Serdang</span>
                    <h2>Semua yang Kamu <span class="accent-glow-text">Butuhkan</span> untuk Menjelajahi <span class="gradient-text-earth">Wisata</span></h2>
                    <p>
                        GeoWisata menyatukan data tempat wisata yang sudah tervalidasi ke dalam peta interaktif berbasis Leaflet dan OpenStreetMap.
                        Jelajahi lokasi terbaru, baca ringkasan destinasi, lalu lanjutkan ke peta untuk melihat posisi sebenarnya.
                    </p>
                    <div class="hero-actions">
HTML;

$lines = file('app/Views/landing_page.php');
// The file currently has lines 1-133
// The part after <div class="hero-actions"> starts at line 5
$rest = implode("", array_slice($lines, 4));

file_put_contents('app/Views/landing_page.php', $content . "\n" . $rest);
echo "Fixed";
