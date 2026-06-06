<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Diagnose Deploy - Tourscape MS</title>
    <style>
        :root {
            color-scheme: light dark;
            --bg: #f6f3ef;
            --card: rgba(255, 255, 255, 0.92);
            --ink: #24180f;
            --muted: #73685f;
            --border: rgba(84, 60, 42, 0.14);
            --ok: #12724d;
            --warn: #a05a12;
            --bad: #ad2e2e;
            --shadow: 0 18px 48px rgba(54, 33, 21, 0.08);
        }

        @media (prefers-color-scheme: dark) {
            :root {
                --bg: #17110d;
                --card: rgba(36, 27, 21, 0.92);
                --ink: #f5efe8;
                --muted: #c6b6aa;
                --border: rgba(255, 241, 230, 0.1);
                --shadow: 0 18px 48px rgba(0, 0, 0, 0.28);
            }
        }

        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: Inter, system-ui, sans-serif;
            background: linear-gradient(180deg, rgba(125, 86, 45, 0.12), transparent 240px), var(--bg);
            color: var(--ink);
        }
        .shell {
            max-width: 1180px;
            margin: 0 auto;
            padding: 32px 20px 48px;
        }
        .hero {
            margin-bottom: 24px;
            padding: 24px;
            border-radius: 24px;
            background: linear-gradient(135deg, rgba(54, 33, 21, 0.92), rgba(110, 74, 44, 0.88));
            color: #fff8f2;
            box-shadow: var(--shadow);
        }
        .hero h1 { margin: 0 0 8px; font-size: 30px; }
        .hero p { margin: 0; line-height: 1.55; color: rgba(255, 248, 242, 0.84); }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 18px;
        }
        .card {
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 22px;
            box-shadow: var(--shadow);
            padding: 20px;
            backdrop-filter: blur(12px);
        }
        .card h2 {
            margin: 0 0 16px;
            font-size: 18px;
        }
        .stack { display: grid; gap: 12px; }
        .row {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            gap: 16px;
            padding-bottom: 10px;
            border-bottom: 1px solid var(--border);
        }
        .row:last-child { padding-bottom: 0; border-bottom: none; }
        .label { color: var(--muted); font-size: 13px; min-width: 120px; }
        .value { text-align: right; word-break: break-word; }
        .pill {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 6px 10px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 700;
        }
        .ok { color: var(--ok); background: rgba(18, 114, 77, 0.12); }
        .warn { color: var(--warn); background: rgba(160, 90, 18, 0.12); }
        .bad { color: var(--bad); background: rgba(173, 46, 46, 0.12); }
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
        }
        th, td {
            padding: 10px 12px;
            border-bottom: 1px solid var(--border);
            text-align: left;
            vertical-align: top;
        }
        th { color: var(--muted); font-weight: 700; }
        code {
            display: inline-block;
            padding: 2px 6px;
            border-radius: 8px;
            background: rgba(54, 33, 21, 0.08);
            color: inherit;
        }
        a { color: inherit; }
    </style>
</head>
<body>
    <div class="shell">
        <section class="hero">
            <h1>Diagnose Deploy Railway</h1>
            <p>Halaman ini membantu cek cepat apakah base URL, asset CSS/JS, writable folder, ekstensi PHP, dan koneksi database sudah terbaca dengan benar setelah deploy.</p>
        </section>

        <div class="grid">
            <section class="card">
                <h2>Ringkasan App</h2>
                <div class="stack">
                    <?php foreach ($summary as $label => $value): ?>
                        <div class="row">
                            <div class="label"><?= esc(ucwords(str_replace('_', ' ', $label))) ?></div>
                            <div class="value"><?= esc((string) $value) ?></div>
                        </div>
                    <?php endforeach; ?>
                </div>
            </section>

            <section class="card">
                <h2>Environment Railway</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Variabel</th>
                            <th>Status</th>
                            <th>Nilai</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($envChecks as $env): ?>
                            <tr>
                                <td><code><?= esc($env['key']) ?></code></td>
                                <td>
                                    <span class="pill <?= $env['set'] ? 'ok' : 'bad' ?>">
                                        <?= $env['set'] ? 'Terisi' : 'Kosong' ?>
                                    </span>
                                </td>
                                <td><?= esc($env['value']) ?></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </section>

            <section class="card">
                <h2>Asset CSS / JS</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Asset</th>
                            <th>URL</th>
                            <th>File</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($assetChecks as $asset): ?>
                            <tr>
                                <td><?= esc($asset['label']) ?></td>
                                <td><a href="<?= esc($asset['url']) ?>" target="_blank" rel="noopener"><?= esc($asset['url']) ?></a></td>
                                <td><code><?= esc($asset['path']) ?></code></td>
                                <td>
                                    <span class="pill <?= $asset['exists'] ? 'ok' : 'bad' ?>">
                                        <?= $asset['exists'] ? 'Ada' : 'Tidak ada' ?>
                                    </span>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </section>

            <section class="card">
                <h2>Writable Folder</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Folder</th>
                            <th>Path</th>
                            <th>Ada</th>
                            <th>Writable</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($writableChecks as $item): ?>
                            <tr>
                                <td><?= esc($item['label']) ?></td>
                                <td><code><?= esc($item['path']) ?></code></td>
                                <td><span class="pill <?= $item['exists'] ? 'ok' : 'bad' ?>"><?= $item['exists'] ? 'Ya' : 'Tidak' ?></span></td>
                                <td><span class="pill <?= $item['writable'] ? 'ok' : 'bad' ?>"><?= $item['writable'] ? 'Ya' : 'Tidak' ?></span></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </section>

            <section class="card">
                <h2>Ekstensi PHP</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Ekstensi</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($extensionChecks as $extension): ?>
                            <tr>
                                <td><code><?= esc($extension['name']) ?></code></td>
                                <td><span class="pill <?= $extension['loaded'] ? 'ok' : 'bad' ?>"><?= $extension['loaded'] ? 'Loaded' : 'Missing' ?></span></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </section>

            <section class="card" style="grid-column: 1 / -1;">
                <h2>Database</h2>
                <div class="stack" style="margin-bottom: 18px;">
                    <div class="row">
                        <div class="label">Koneksi</div>
                        <div class="value">
                            <span class="pill <?= $dbChecks['connected'] ? 'ok' : 'bad' ?>">
                                <?= $dbChecks['connected'] ? 'Terhubung' : 'Gagal' ?>
                            </span>
                        </div>
                    </div>
                    <div class="row">
                        <div class="label">Pesan</div>
                        <div class="value"><?= esc($dbChecks['message']) ?></div>
                    </div>
                    <div class="row">
                        <div class="label">Versi</div>
                        <div class="value"><?= esc($dbChecks['version']) ?></div>
                    </div>
                    <div class="row">
                        <div class="label">Schema Aktif</div>
                        <div class="value"><?= esc($dbChecks['schema']) ?></div>
                    </div>
                </div>

                <table>
                    <thead>
                        <tr>
                            <th>Tabel</th>
                            <th>Status</th>
                            <th>Jumlah Data</th>
                            <th>Error</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($dbChecks['tables'] as $table): ?>
                            <tr>
                                <td><code><?= esc($table['name']) ?></code></td>
                                <td><span class="pill <?= $table['ok'] ? 'ok' : 'bad' ?>"><?= $table['ok'] ? 'OK' : 'Gagal' ?></span></td>
                                <td><?= esc((string) $table['count']) ?></td>
                                <td><?= esc($table['error'] ?? '-') ?></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </section>
        </div>
    </div>
</body>
</html>
