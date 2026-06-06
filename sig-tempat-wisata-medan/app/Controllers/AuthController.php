<?php

namespace App\Controllers;

class AuthController extends BaseController
{
    private function supabaseConfig(string $key): string
    {
        $fallback = match ($key) {
            'url'    => 'https://ekslfvczghsmiqkothdm.supabase.co',
            'key'    => 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVrc2xmdmN6Z2hzbWlxa290aGRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5ODc3ODYsImV4cCI6MjA5MDU2Mzc4Nn0.uFwuatl1DX8Xlhdb70fhgc7AJrD-OVb5xczOUQ4503Y',
            'bucket' => 'gis wisata',
            default  => '',
        };

        $preferred = match ($key) {
            'url'    => env('SUPABASE_URL'),
            'key'    => env('SUPABASE_KEY'),
            'bucket' => env('SUPABASE_BUCKET'),
            default  => null,
        };

        if ($preferred !== null && $preferred !== false && $preferred !== '') {
            return (string) $preferred;
        }

        return (string) env('supabase.' . $key, $fallback);
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
