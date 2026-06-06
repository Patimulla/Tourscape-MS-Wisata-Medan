<?php

namespace App\Controllers;

class AuthController extends BaseController
{
    private function supabaseConfig(string $key): string
    {
        $preferred = match ($key) {
            'url'    => env('SUPABASE_URL'),
            'key'    => env('SUPABASE_KEY'),
            'bucket' => env('SUPABASE_BUCKET'),
            default  => null,
        };

        if ($preferred !== null && $preferred !== false && $preferred !== '') {
            return (string) $preferred;
        }

        return (string) env('supabase.' . $key, '');
    }

    public function login()
    {
        if (session()->get('admin_logged_in')) {
            return redirect()->to('/admin/dashboard');
        }
        return view('admin_login');
    }

    public function attemptLogin()
    {
        $email = $this->request->getPost('email');
        $password = $this->request->getPost('password');

        $url = rtrim($this->supabaseConfig('url'), '/') . '/auth/v1/token?grant_type=password';
        $key = $this->supabaseConfig('key');

        if ($url === '/auth/v1/token?grant_type=password' || $key === '') {
            return redirect()->back()->with('error', 'Konfigurasi Supabase belum lengkap di server.');
        }

        $client = \Config\Services::curlrequest();
        try {
            $response = $client->post($url, [
                'headers' => [
                    'apikey' => $key,
                    'Content-Type' => 'application/json'
                ],
                'json' => [
                    'email' => $email,
                    'password' => $password
                ],
                'http_errors' => false
            ]);

            if ($response->getStatusCode() === 200) {
                $body = json_decode($response->getBody());
                session()->set('admin_logged_in', true);
                session()->set('admin_token', $body->access_token);
                return redirect()->to('/admin/dashboard');
            } else {
                return redirect()->back()->with('error', 'Login gagal. Email atau password salah.');
            }
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Terjadi kesalahan sistem: ' . $e->getMessage());
        }
    }

    public function logout()
    {
        session()->destroy();
        return redirect()->to('/admin/login');
    }
}
