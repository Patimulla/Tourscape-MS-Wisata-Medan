<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>About - Tourscape MS</title>

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">

    <link rel="stylesheet" href="<?= base_url('css/terra-medan.css') ?>?v=3.0">
    <link rel="stylesheet" href="<?= base_url('css/stitch-pages.css') ?>?v=3.0">

    <style>
        .site-page {
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .about-section {
            padding: 80px 24px;
            max-width: 1200px;
            margin: 0 auto;
            flex: 1;
        }

        .about-website {
            text-align: center;
            margin-bottom: 60px;
        }

        .about-website h1 {
            font-size: 2.8rem;
            color: var(--tm-primary);
            margin-bottom: 32px;
            font-family: var(--tm-font-display);
        }

        .about-content-text {
            max-width: 860px;
            margin: 0 auto;
            text-align: left;
            display: flex;
            flex-direction: column;
            gap: 20px;
        }

        .about-content-text p {
            font-size: 1.1rem;
            color: var(--text-secondary);
            line-height: 1.8;
            margin: 0;
            text-align: justify;
        }

        .section-title {
            text-align: center;
            font-family: var(--tm-font-display);
            font-size: 2.2rem;
            color: var(--tm-primary);
            margin-bottom: 40px;
        }

        .about-us-section {
            background: var(--tm-gradient-warm);
            padding: 60px 40px;
            border-radius: var(--tm-radius-xl);
            box-shadow: var(--tm-shadow-soft);
            margin-bottom: 60px;
        }

        .admin-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 32px;
        }

        .admin-card {
            background: var(--bg-card);
            border-radius: var(--tm-radius-lg);
            padding: 40px 24px;
            text-align: center;
            box-shadow: var(--shadow-sm);
            border: 1px solid var(--border-color);
            transition: all var(--tm-transition);
            display: flex;
            flex-direction: column;
            align-items: center;
        }

        .admin-card:hover {
            transform: translateY(-8px);
            box-shadow: var(--shadow-md);
            border-color: var(--border-hover);
        }

        .admin-photo {
            width: 140px;
            height: 140px;
            border-radius: 50%;
            object-fit: cover;
            margin: 0 auto 24px;
            border: 4px solid var(--tm-surface);
            box-shadow: 0 8px 16px rgba(0,0,0,0.1);
        }

        .admin-placeholder {
            width: 140px;
            height: 140px;
            border-radius: 50%;
            margin: 0 auto 24px;
            background: var(--tm-gradient-brand);
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            font-size: 3rem;
            font-weight: 700;
            border: 4px solid var(--tm-surface);
            box-shadow: 0 8px 16px rgba(0,0,0,0.1);
        }

        .admin-name {
            font-family: var(--tm-font-display);
            font-size: 1.25rem;
            color: var(--tm-on-surface);
            margin-bottom: 6px;
            font-weight: 700;
            line-height: 1.4;
        }

        .admin-role {
            font-size: 0.95rem;
            color: var(--tm-tertiary);
            font-weight: 700;
            margin-bottom: 12px;
        }
        
        .admin-desc {
            font-size: 0.9rem;
            color: var(--text-secondary);
            line-height: 1.6;
        }

        .contact-us-section {
            background: linear-gradient(135deg, rgba(255, 255, 255, 0.7) 0%, rgba(255, 255, 255, 0.4) 100%);
            backdrop-filter: blur(10px);
            -webkit-backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.5);
            padding: 80px 40px;
            border-radius: var(--tm-radius-xl);
            text-align: center;
            position: relative;
            box-shadow: 0 10px 30px rgba(0,0,0,0.02);
            overflow: hidden;
            margin-bottom: 40px;
        }

        .contact-us-section::before {
            content: '';
            position: absolute;
            top: -100px;
            left: -100px;
            width: 300px;
            height: 300px;
            background: var(--tm-gradient-warm);
            border-radius: 50%;
            filter: blur(80px);
            opacity: 0.15;
            z-index: 0;
            pointer-events: none;
        }

        .contact-us-section::after {
            content: '';
            position: absolute;
            bottom: -100px;
            right: -100px;
            width: 300px;
            height: 300px;
            background: var(--tm-gradient-brand);
            border-radius: 50%;
            filter: blur(80px);
            opacity: 0.15;
            z-index: 0;
            pointer-events: none;
        }

        .contact-us-section > * {
            position: relative;
            z-index: 1;
        }

        .contact-subtitle {
            font-size: 1.1rem;
            color: var(--text-secondary);
            margin-bottom: 50px;
            max-width: 600px;
            margin-left: auto;
            margin-right: auto;
            line-height: 1.6;
        }

        .contact-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 24px;
            max-width: 1000px;
            margin: 0 auto;
        }

        .contact-card {
            background: rgba(255, 255, 255, 0.85);
            backdrop-filter: blur(12px);
            -webkit-backdrop-filter: blur(12px);
            border: 1px solid rgba(255, 255, 255, 0.6);
            padding: 32px 24px;
            border-radius: var(--tm-radius-lg);
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.04);
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            gap: 16px;
            transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            position: relative;
            z-index: 2;
        }

        .contact-card:hover {
            transform: translateY(-8px);
            border-color: rgba(56, 189, 248, 0.4);
            box-shadow: 0 16px 32px rgba(56, 189, 248, 0.15);
            background: #ffffff;
        }

        .contact-icon-wrapper {
            width: 56px;
            height: 56px;
            background: var(--tm-gradient-brand);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            margin-bottom: 8px;
            box-shadow: 0 8px 16px rgba(16, 185, 129, 0.25);
            transition: transform 0.3s ease;
        }

        .contact-card:hover .contact-icon-wrapper {
            transform: scale(1.1) rotate(5deg);
        }

        .contact-card strong {
            color: var(--tm-on-surface);
            font-size: 1.2rem;
            font-family: var(--tm-font-display);
            font-weight: 700;
        }

        .contact-card a {
            color: var(--tm-info);
            text-decoration: none;
            font-weight: 600;
            font-size: 0.85rem;
            word-break: break-all;
            text-align: center;
            padding: 12px 16px;
            background: rgba(56, 189, 248, 0.08);
            border-radius: 50px;
            width: 100%;
            box-sizing: border-box;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            border: 1px solid transparent;
        }

        .contact-card a:hover {
            background: var(--tm-info);
            color: white;
            box-shadow: 0 6px 16px rgba(56, 189, 248, 0.3);
            transform: translateY(-2px);
        }

        @media (max-width: 992px) {
            .admin-grid {
                grid-template-columns: repeat(2, 1fr);
            }
        }

        @media (max-width: 768px) {
            .admin-grid {
                grid-template-columns: 1fr;
            }
        }

        /* Dark Mode adjustments */
        body.dark .about-website h1,
        body.dark .section-title,
        body.dark .admin-name,
        body.dark .contact-card strong {
            color: var(--tm-on-surface);
        }
        
        body.dark .about-us-section {
            background: rgba(30, 41, 59, 0.4);
            border-color: rgba(255, 255, 255, 0.05);
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }

        body.dark .contact-card {
            background: rgba(30, 41, 59, 0.6);
            border-color: rgba(255, 255, 255, 0.05);
            box-shadow: 0 8px 24px rgba(0,0,0,0.2);
        }

        body.dark .contact-card:hover {
            background: rgba(30, 41, 59, 0.9);
            border-color: rgba(56, 189, 248, 0.3);
            box-shadow: 0 16px 32px rgba(0,0,0,0.3);
        }
        
        body.dark .contact-icon-wrapper {
            box-shadow: 0 8px 16px rgba(0,0,0,0.4);
        }

        body.dark .contact-card a {
            background: rgba(56, 189, 248, 0.15);
            color: #38bdf8;
        }

        body.dark .contact-card a:hover {
            background: #38bdf8;
            color: #0f172a;
            box-shadow: 0 6px 16px rgba(56, 189, 248, 0.3);
        }
    </style>
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

    <?= view('layout/navbar', ['activePage' => 'about']) ?>

    <main class="about-section">
        <!-- TENTANG WEBSITE -->
        <section class="about-website">
            <h1>Tentang Tourscape MS</h1>
            <div class="about-content-text">
                <p>
                    Tourscape MS adalah platform pemetaan interaktif yang dirancang untuk membantu wisatawan dan masyarakat menemukan, merencanakan, serta mengeksplorasi keindahan destinasi wisata yang ada di kawasan Kota Medan dan Kabupaten Deli Serdang. Sistem ini mengintegrasikan teknologi Sistem Informasi Geografis (SIG) modern untuk memberikan pengalaman navigasi yang mulus dan informatif.
                </p>
                <p>
                    Proyek ini dibangun dengan visi mendigitalkan informasi pariwisata lokal agar lebih mudah diakses oleh publik, sekaligus mempromosikan kekayaan budaya dan alam di Sumatera Utara. Kami mengumpulkan data secara langsung dan melakukan kurasi untuk memastikan informasi rute, fasilitas, serta koordinat lokasi sangat akurat.
                </p>
                <p>
                    Lebih dari sekadar peta, Tourscape MS merupakan sebuah ekosistem yang menggabungkan aplikasi mobile untuk pengelolaan di lapangan dan dashboard website untuk visualisasi secara luas. Melalui platform ini, kami berharap dapat mendukung pertumbuhan sektor pariwisata daerah serta memberikan kemudahan eksplorasi bagi siapa saja yang ingin mengenal lebih dekat pesona Medan dan Deli Serdang.
                </p>
            </div>
        </section>

        <!-- TEKNOLOGI -->
        <section class="tech-section" style="margin-bottom: 60px; text-align: center;">
            <h2 class="section-title">Teknologi di Balik Layar</h2>
            <p style="color: var(--text-secondary); max-width: 600px; margin: 0 auto 30px; line-height: 1.6;">Platform ini dibangun dengan memanfaatkan stack teknologi web modern untuk memastikan performa yang cepat dan pengalaman navigasi peta yang interaktif.</p>
            <div style="display: flex; justify-content: center; gap: 20px; flex-wrap: wrap;">
                <span class="tm-chip" style="font-size: 0.9rem; padding: 10px 16px;">CodeIgniter 4</span>
                <span class="tm-chip" style="font-size: 0.9rem; padding: 10px 16px;">Leaflet JS</span>
                <span class="tm-chip" style="font-size: 0.9rem; padding: 10px 16px;">OpenStreetMap</span>
                <span class="tm-chip" style="font-size: 0.9rem; padding: 10px 16px;">PostgreSQL & PostGIS</span>
                <span class="tm-chip" style="font-size: 0.9rem; padding: 10px 16px;">Flutter (Mobile)</span>
            </div>
        </section>

        <!-- FITUR UNGGULAN -->
        <section class="features-section" style="margin-bottom: 60px;">
            <h2 class="section-title">Fitur Unggulan</h2>
            <div class="features-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 30px;">
                <div class="feature-card" style="background: var(--bg-card); padding: 30px; border-radius: var(--tm-radius-lg); border: 1px solid var(--border-color); text-align: center; box-shadow: var(--shadow-sm);">
                    <div class="feature-icon" style="background: var(--tm-gradient-brand); color: white; width: 64px; height: 64px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 24px;">🗺️</div>
                    <h3 style="color: var(--tm-primary); margin-bottom: 15px; font-family: var(--tm-font-display);">Peta Interaktif</h3>
                    <p style="color: var(--text-secondary); line-height: 1.6;">Jelajahi berbagai destinasi wisata melalui peta digital yang mudah digunakan, lengkap dengan filter kategori untuk memudahkan pencarian lokasi idaman Anda.</p>
                </div>
                <div class="feature-card" style="background: var(--bg-card); padding: 30px; border-radius: var(--tm-radius-lg); border: 1px solid var(--border-color); text-align: center; box-shadow: var(--shadow-sm);">
                    <div class="feature-icon" style="background: var(--tm-gradient-warm); color: white; width: 64px; height: 64px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 24px;">📍</div>
                    <h3 style="color: var(--tm-primary); margin-bottom: 15px; font-family: var(--tm-font-display);">Navigasi Rute</h3>
                    <p style="color: var(--text-secondary); line-height: 1.6;">Dapatkan panduan arah secara real-time dari lokasi Anda ke destinasi wisata yang dituju berkat integrasi teknologi Leaflet Routing Machine.</p>
                </div>
                <div class="feature-card" style="background: var(--bg-card); padding: 30px; border-radius: var(--tm-radius-lg); border: 1px solid var(--border-color); text-align: center; box-shadow: var(--shadow-sm);">
                    <div class="feature-icon" style="background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; width: 64px; height: 64px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 24px;">📱</div>
                    <h3 style="color: var(--tm-primary); margin-bottom: 15px; font-family: var(--tm-font-display);">Aplikasi Mobile Terintegrasi</h3>
                    <p style="color: var(--text-secondary); line-height: 1.6;">Selain website untuk eksplorasi publik, kami menyediakan aplikasi mobile khusus untuk pengelolaan dan pengajuan titik lokasi wisata baru oleh petugas.</p>
                </div>
                <div class="feature-card" style="background: var(--bg-card); padding: 30px; border-radius: var(--tm-radius-lg); border: 1px solid var(--border-color); text-align: center; box-shadow: var(--shadow-sm);">
                    <div class="feature-icon" style="background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%); color: white; width: 64px; height: 64px; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px; font-size: 24px;">🛡️</div>
                    <h3 style="color: var(--tm-primary); margin-bottom: 15px; font-family: var(--tm-font-display);">Validasi Data Ketat</h3>
                    <p style="color: var(--text-secondary); line-height: 1.6;">Setiap titik wisata yang masuk akan melalui proses validasi oleh admin pusat guna memastikan informasi akurat, terpercaya, dan aman dikunjungi masyarakat.</p>
                </div>
            </div>
        </section>

        <?php
        // Definisi role dan deskripsi
        $rolesMap = [
            'Pati' => [
                'name' => 'Pati Mula Sadra Siregar',
                'role' => 'Full-Stack Developer & Mobile',
                'desc' => 'Bertanggung jawab atas arsitektur sistem, integrasi database, dan pengembangan fitur aplikasi secara menyeluruh.'
            ],
            'Samalona' => [
                'name' => 'Samalona Simanjuntak',
                'role' => 'Mobile Developer & UI/UX Designer',
                'desc' => 'Fokus menciptakan pengalaman visual yang intuitif dan mengembangkan antarmuka aplikasi mobile yang responsif.'
            ],
            'Amel' => [
                'name' => 'Amelia Cahya Nabila',
                'role' => 'Data Entry',
                'desc' => 'Berperan dalam pengumpulan, validasi, dan input data lokasi wisata agar selalu akurat dan terkini.'
            ],
            'Calysta' => [
                'name' => 'Calysta Adelia',
                'role' => 'Data Entry',
                'desc' => 'Bertugas mengelola informasi destinasi, memverifikasi koordinat peta, serta memastikan kelengkapan data.'
            ],
            'Masro' => [
                'name' => 'Masro A Lumbanraja',
                'role' => 'Data Entry',
                'desc' => 'Memfokuskan diri pada survei pustaka, rekapitulasi data lapangan, dan dokumentasi aset wisata.'
            ],
            'Mika' => [
                'name' => 'Mika N Sianturi',
                'role' => 'Data Entry',
                'desc' => 'Mengkurasi detail wisata, mengelola entri galeri foto, serta memastikan standar informasi publik yang berkualitas.'
            ]
        ];

        // Urutkan data berdasarkan target
        $orderedAdmins = [];
        $targetOrder = ['Pati', 'Samalona', 'Amel', 'Calysta', 'Masro', 'Mika'];

        if (!empty($admins)) {
            foreach ($targetOrder as $shortName) {
                foreach ($admins as $admin) {
                    if (stripos($admin['username'], $shortName) !== false) {
                        $orderedAdmins[] = [
                            'db' => $admin,
                            'meta' => $rolesMap[$shortName]
                        ];
                        break;
                    }
                }
            }
        }
        ?>

        <!-- ABOUT US -->
        <section class="about-us-section">
            <h2 class="section-title">About Us</h2>
            <div class="admin-grid">
                <?php if (!empty($orderedAdmins)): ?>
                    <?php foreach ($orderedAdmins as $item): 
                        $admin = $item['db'];
                        $meta = $item['meta'];
                    ?>
                        <div class="admin-card">
                            <?php if (!empty($admin['foto_profil'])): ?>
                                <img src="<?= esc($admin['foto_profil']) ?>" alt="<?= esc($meta['name']) ?>" class="admin-photo">
                            <?php else: ?>
                                <div class="admin-placeholder">
                                    <?= esc(strtoupper(substr($meta['name'], 0, 1))) ?>
                                </div>
                            <?php endif; ?>
                            
                            <h3 class="admin-name"><?= esc($meta['name']) ?></h3>
                            <div class="admin-role"><?= esc($meta['role']) ?></div>
                            <div class="admin-desc">"<?= esc($meta['desc']) ?>"</div>
                        </div>
                    <?php endforeach; ?>
                <?php else: ?>
                    <p style="text-align: center; width: 100%; color: var(--text-secondary); grid-column: 1 / -1;">Tidak ada data admin yang ditemukan.</p>
                <?php endif; ?>
            </div>
        </section>
        
        <!-- CONTACT US -->
        <section class="contact-us-section">
            <h2 class="section-title">Contact Us</h2>
            <p class="contact-subtitle">Punya pertanyaan atau ingin berkolaborasi? Hubungi tim kami melalui email di bawah ini:</p>
            <div class="contact-grid">
                <?php if (!empty($orderedAdmins)): ?>
                    <?php foreach ($orderedAdmins as $item): 
                        $meta = $item['meta'];
                        // Generate mock email based on full name
                        $fullNameLower = strtolower(str_replace(' ', '', $meta['name']));
                        $email = $fullNameLower . '@students.polmed.ac.id';
                    ?>
                        <div class="contact-card">
                            <div class="contact-icon-wrapper">
                                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <rect x="2" y="4" width="20" height="16" rx="2"></rect>
                                    <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"></path>
                                </svg>
                            </div>
                            <strong><?= esc($meta['name']) ?></strong>
                            <a href="mailto:<?= esc($email) ?>">
                                <?= esc($email) ?>
                            </a>
                        </div>
                    <?php endforeach; ?>
                <?php else: ?>
                    <p style="text-align: center; width: 100%; color: var(--text-secondary); grid-column: 1 / -1;">Data kontak tidak tersedia.</p>
                <?php endif; ?>
            </div>
        </section>
    </main>

    <script>
        // Theme toggle logic similar to landing_page.js
        const btnToggle = document.getElementById('btn-dark-mode-beranda');
        const iconDark = document.getElementById('beranda-icon-dark');
        const iconLight = document.getElementById('beranda-icon-light');

        function updateIcon() {
            if (document.body.classList.contains('dark')) {
                iconDark.style.display = 'none';
                iconLight.style.display = 'block';
            } else {
                iconDark.style.display = 'block';
                iconLight.style.display = 'none';
            }
        }

        if (btnToggle) {
            btnToggle.addEventListener('click', () => {
                const isDark = document.body.classList.toggle('dark');
                localStorage.setItem('terra-dark-mode', isDark);
                updateIcon();
            });
            updateIcon();
        }
    </script>
</body>
</html>
