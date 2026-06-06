<?php
$content = file_get_contents('app/Views/landing_page.php');

$pattern = '/<div class="hero-actions">\s*<h3 style="font-size: 1\.8rem; margin-top: 8px;">Data mobile, validasi web, dan peta publik dalam satu alur\.<\/h3>\s*<\/div>/';

$replace = <<<HTML
                    <div class="hero-actions">
                        <a href="/peta" class="tm-btn tm-btn-primary">Buka Peta Interaktif</a>
                    </div>
                </div>

                <div class="hero-visual">
                    <div>
                        <span class="tm-kicker" style="color: rgba(255,255,255,0.82);">Sistem Terhubung</span>
                        <h3 style="font-size: 1.8rem; margin-top: 8px;">Data mobile, validasi web, dan peta publik dalam satu alur.</h3>
                    </div>
HTML;

$newContent = preg_replace($pattern, $replace, $content);
file_put_contents('app/Views/landing_page.php', $newContent);
echo "Regex fix complete.\n";
