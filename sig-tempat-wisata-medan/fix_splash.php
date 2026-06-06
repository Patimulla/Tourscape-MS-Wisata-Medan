<?php
$content = file_get_contents('app/Views/splash_page.php');

// Remove Admin link from navbar
$search1 = '<a class="splash-nav-link" href="/admin">Admin</a>';
$content = str_replace($search1, '', $content);

// Remove Dashboard Admin card
$search2 = <<<HTML
                <div class="splash-feature-card glass-card" data-anim="fadeUp" data-delay="400">
                    <div class="feature-icon-wrap">
                        <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><line x1="3" y1="9" x2="21" y2="9"></line><line x1="9" y1="21" x2="9" y2="9"></line></svg>
                    </div>
                    <h3>Dashboard Admin</h3>
                    <p>Kelola data wisata, validasi submission pengguna, dan pantau aktivitas dari dashboard admin lengkap.</p>
                </div>
HTML;
$content = str_replace($search2, '', $content);

file_put_contents('app/Views/splash_page.php', $content);
echo "Fixed splash page\n";
