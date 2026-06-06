<?php

namespace App\Controllers;

use CodeIgniter\Exceptions\PageNotFoundException;
use CodeIgniter\HTTP\ResponseInterface;
use Config\Database;

class DeployController extends BaseController
{
    public function health(): ResponseInterface
    {
        return $this->response->setJSON([
            'status'      => 'ok',
            'environment' => ENVIRONMENT,
            'app'         => 'Tourscape MS Web',
            'time'        => date(DATE_ATOM),
        ]);
    }

    public function diagnose(): string|ResponseInterface
    {
        if (!$this->envToBool($this->envValue('APP_DIAGNOSE_ENABLED', ENVIRONMENT !== 'production'))) {
            throw PageNotFoundException::forPageNotFound();
        }

        $expectedKey = $this->envValue('APP_DIAGNOSE_KEY', '');

        if ($expectedKey !== '' && $this->request->getGet('key') !== $expectedKey) {
            return $this->response
                ->setStatusCode(403)
                ->setBody('Akses diagnosis ditolak. Tambahkan key yang benar pada URL.');
        }

        helper('url');

        $appConfig = config('App');
        $dbConfig  = config('Database');

        return view('diagnose_page', [
            'summary'        => $this->buildSummary($appConfig, $dbConfig),
            'assetChecks'    => $this->buildAssetChecks(),
            'writableChecks' => $this->buildWritableChecks(),
            'extensionChecks'=> $this->buildExtensionChecks(),
            'dbChecks'       => $this->buildDatabaseChecks($dbConfig),
            'envChecks'      => $this->buildEnvChecks(),
        ]);
    }

    private function buildSummary(object $appConfig, object $dbConfig): array
    {
        return [
            'environment'      => ENVIRONMENT,
            'base_url'         => $appConfig->baseURL,
            'site_url_home'    => site_url('/'),
            'request_url'      => current_url(true)->__toString(),
            'request_host'     => $this->request->getServer('HTTP_HOST') ?? '-',
            'request_scheme'   => $this->request->isSecure() ? 'https' : 'http',
            'forwarded_proto'  => $this->request->getServer('HTTP_X_FORWARDED_PROTO') ?? '-',
            'forwarded_host'   => $this->request->getServer('HTTP_X_FORWARDED_HOST') ?? '-',
            'index_page'       => $appConfig->indexPage === '' ? '(kosong)' : $appConfig->indexPage,
            'force_https'      => $appConfig->forceGlobalSecureRequests ? 'true' : 'false',
            'db_driver'        => $dbConfig->default['DBDriver'] ?? '-',
            'db_host'          => $dbConfig->default['hostname'] ?? '-',
            'db_database'      => $dbConfig->default['database'] ?? '-',
            'db_port'          => (string) ($dbConfig->default['port'] ?? '-'),
            'db_schema'        => $dbConfig->default['schema'] ?? '-',
            'db_sslmode'       => $dbConfig->default['sslmode'] ?? '-',
        ];
    }

    private function buildAssetChecks(): array
    {
        $checks = [
            ['label' => 'CSS Terra Medan', 'url' => base_url('css/terra-medan.css'), 'path' => FCPATH . 'css/terra-medan.css'],
            ['label' => 'CSS Explore/UI', 'url' => base_url('css/stitch-pages.css'), 'path' => FCPATH . 'css/stitch-pages.css'],
            ['label' => 'CSS Web GIS', 'url' => base_url('css/webgis.css'), 'path' => FCPATH . 'css/webgis.css'],
            ['label' => 'JS Peta', 'url' => base_url('js/webgis.js'), 'path' => FCPATH . 'js/webgis.js'],
            ['label' => 'Hero Image', 'url' => base_url('images/hero-medan.png'), 'path' => FCPATH . 'images/hero-medan.png'],
        ];

        return array_map(static function (array $item): array {
            $item['exists'] = is_file($item['path']);
            return $item;
        }, $checks);
    }

    private function buildWritableChecks(): array
    {
        $paths = [
            'WRITEPATH root' => WRITEPATH,
            'cache'          => WRITEPATH . 'cache',
            'logs'           => WRITEPATH . 'logs',
            'session'        => WRITEPATH . 'session',
            'uploads'        => WRITEPATH . 'uploads',
        ];

        $checks = [];

        foreach ($paths as $label => $path) {
            $checks[] = [
                'label'      => $label,
                'path'       => $path,
                'exists'     => is_dir($path),
                'writable'   => is_writable($path),
            ];
        }

        return $checks;
    }

    private function buildExtensionChecks(): array
    {
        $extensions = [
            'curl',
            'intl',
            'mbstring',
            'pgsql',
            'pdo_pgsql',
            'json',
            'openssl',
        ];

        return array_map(static fn(string $name): array => [
            'name'   => $name,
            'loaded' => extension_loaded($name),
        ], $extensions);
    }

    private function buildDatabaseChecks(object $dbConfig): array
    {
        $result = [
            'connected' => false,
            'message'   => 'Belum dicek',
            'version'   => '-',
            'schema'    => $dbConfig->default['schema'] ?? '-',
            'tables'    => [],
        ];

        try {
            $db = Database::connect();
            $db->initialize();

            $versionRow = $db->query('SELECT version() AS version, current_schema() AS schema_name')->getRowArray() ?? [];

            $result['connected'] = true;
            $result['message']   = 'Koneksi database berhasil.';
            $result['version']   = $versionRow['version'] ?? '-';
            $result['schema']    = $versionRow['schema_name'] ?? ($dbConfig->default['schema'] ?? '-');

            foreach (['wisata', 'kategori', 'admin_mobile', 'review'] as $table) {
                try {
                    $count = $db->table($table)->countAllResults();
                    $result['tables'][] = [
                        'name'  => $table,
                        'count' => $count,
                        'ok'    => true,
                    ];
                } catch (\Throwable $tableError) {
                    $result['tables'][] = [
                        'name'  => $table,
                        'count' => '-',
                        'ok'    => false,
                        'error' => $tableError->getMessage(),
                    ];
                }
            }
        } catch (\Throwable $e) {
            $result['message'] = $e->getMessage();
        }

        return $result;
    }

    private function buildEnvChecks(): array
    {
        $keys = [
            'CI_ENVIRONMENT',
            'APP_BASE_URL',
            'APP_FORCE_HTTPS',
            'DATABASE_URL',
            'DB_DRIVER',
            'DB_HOST',
            'DB_PORT',
            'DB_DATABASE',
            'DB_USERNAME',
            'DB_PASSWORD',
            'DB_SCHEMA',
            'DB_SSLMODE',
            'SUPABASE_URL',
            'SUPABASE_KEY',
            'SUPABASE_BUCKET',
            'APP_DIAGNOSE_ENABLED',
            'APP_DIAGNOSE_KEY',
        ];

        $checks = [];

        foreach ($keys as $key) {
            $value = env($key);
            $checks[] = [
                'key'   => $key,
                'set'   => $value !== null && $value !== false && $value !== '',
                'value' => $this->maskEnvValue($key, $value),
            ];
        }

        return $checks;
    }

    private function envValue(string $key, mixed $default = null): mixed
    {
        $value = env($key);

        if ($value !== null && $value !== false && $value !== '') {
            return $value;
        }

        return $default;
    }

    private function envToBool(mixed $value): bool
    {
        if (is_bool($value)) {
            return $value;
        }

        return in_array(strtolower(trim((string) $value)), ['1', 'true', 'yes', 'on'], true);
    }

    private function maskEnvValue(string $key, mixed $value): string
    {
        if ($value === null || $value === false || $value === '') {
            return '(kosong)';
        }

        $stringValue = (string) $value;

        if (in_array($key, ['DB_PASSWORD', 'SUPABASE_KEY', 'APP_DIAGNOSE_KEY'], true)) {
            if (strlen($stringValue) <= 8) {
                return str_repeat('*', strlen($stringValue));
            }

            return substr($stringValue, 0, 4) . str_repeat('*', max(strlen($stringValue) - 8, 4)) . substr($stringValue, -4);
        }

        return $stringValue;
    }
}
