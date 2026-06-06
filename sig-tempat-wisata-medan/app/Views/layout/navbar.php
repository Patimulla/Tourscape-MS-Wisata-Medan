<?php
$headerIdAttr = isset($headerId) ? 'id="' . esc($headerId) . '"' : '';
$headerClassAttr = isset($headerClass) ? 'class="site-topbar ' . esc($headerClass) . '"' : 'class="site-topbar"';
$innerClassAttr = isset($innerClass) ? 'class="tm-shell site-topbar-inner ' . esc($innerClass) . '"' : 'class="tm-shell site-topbar-inner"';
$activePage = $activePage ?? '';
?>
<header <?= $headerIdAttr ?> <?= $headerClassAttr ?>>
    <div <?= $innerClassAttr ?>>
        <a href="<?= site_url('/') ?>" class="site-brand" style="text-decoration:none;">
            <div class="site-brand-mark">
                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 1 1 18 0z"></path>
                    <circle cx="12" cy="10" r="3"></circle>
                </svg>
            </div>
            <h1>Tourscape MS</h1>
        </a>

        <nav class="site-nav">
            <a class="site-nav-link <?= ($activePage === 'home') ? 'active' : '' ?>" href="<?= site_url('/') ?>">Home</a>
            <a class="site-nav-link <?= ($activePage === 'explore') ? 'active' : '' ?>" href="<?= site_url('explore') ?>">Explore</a>
            <a class="site-nav-link <?= ($activePage === 'peta') ? 'active' : '' ?>" href="<?= site_url('peta') ?>">Peta Interaktif</a>
            <a class="site-nav-link <?= ($activePage === 'about') ? 'active' : '' ?>" href="<?= site_url('about') ?>">About</a>
            <?php if(session()->get('admin_logged_in') && !in_array($activePage ?? '', ['explore', 'peta', 'about'])): ?>
                <a class="site-nav-link <?= ($activePage === 'admin') ? 'active' : '' ?>" href="<?= site_url('admin') ?>">Admin Panel</a>
                <a class="site-nav-link" href="<?= site_url('admin/logout') ?>" style="color: var(--tm-danger); border-color: var(--tm-danger);">Logout</a>
            <?php endif; ?>
        </nav>

        <div style="display: flex; align-items: center; gap: 8px;">
            <?php if ($activePage === 'peta'): ?>
            <button id="btn-my-location" class="site-dark-toggle" title="Lokasi Saya" aria-label="Lokasi Saya">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polygon points="3 11 22 2 13 21 11 13 3 11"></polygon>
                </svg>
            </button>
            <?php endif; ?>

            <button id="btn-dark-mode-beranda" class="site-dark-toggle" title="Toggle Dark Mode" aria-label="Toggle Dark Mode">
                <svg id="beranda-icon-dark" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
                </svg>
                <svg id="beranda-icon-light" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="display:none">
                    <circle cx="12" cy="12" r="5"></circle>
                    <line x1="12" y1="1" x2="12" y2="3"></line>
                    <line x1="12" y1="21" x2="12" y2="23"></line>
                    <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
                    <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
                    <line x1="1" y1="12" x2="3" y2="12"></line>
                    <line x1="21" y1="12" x2="23" y2="12"></line>
                    <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
                    <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
                </svg>
            </button>
        </div>
    </div>
</header>
