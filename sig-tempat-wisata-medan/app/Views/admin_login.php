<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login Admin - Tourscape MS</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@600;700;800&family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="/css/terra-medan.css?v=3.0">
    <link rel="stylesheet" href="/css/stitch-pages.css?v=4.0">
    <link rel="stylesheet" href="/css/admin.css?v=4.0">
    <style>
        .login-wrapper {
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: calc(100vh - 120px);
            padding: 20px;
        }
        .login-card {
            width: 100%;
            max-width: 400px;
            padding: 32px;
            border-radius: var(--tm-radius-lg);
        }
        .login-title {
            text-align: center;
            margin-bottom: 24px;
        }
        .login-title h2 {
            color: var(--tm-primary);
            font-size: 1.8rem;
        }
        body.dark .login-title h2 {
            color: var(--tm-on-surface);
        }
        .form-group {
            margin-bottom: 16px;
        }
        .form-group label {
            display: block;
            margin-bottom: 8px;
            color: var(--text-secondary);
            font-weight: 500;
        }
        .form-group input {
            width: 100%;
            padding: 12px 16px;
            border: 1px solid rgba(178, 216, 208, 0.82);
            border-radius: 8px;
            background: rgba(255, 255, 255, 0.8);
            color: var(--tm-on-surface);
            font-family: inherit;
            transition: all 0.2s ease;
        }
        body.dark .form-group input {
            background: rgba(0, 0, 0, 0.2);
            border-color: rgba(69, 51, 43, 0.94);
        }
        .form-group input:focus {
            outline: none;
            border-color: var(--tm-primary);
            box-shadow: 0 0 0 3px rgba(217, 119, 6, 0.2);
        }
        .btn-login {
            width: 100%;
            margin-top: 10px;
            justify-content: center;
        }
        .alert-error {
            background: rgba(239, 68, 68, 0.1);
            color: #ef4444;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 16px;
            font-size: 0.9rem;
            text-align: center;
            border: 1px solid rgba(239, 68, 68, 0.2);
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

    <?= view('layout/navbar', ['activePage' => 'admin']) ?>

    <main class="site-main">
        <div class="login-wrapper">
            <div class="login-card tm-card">
                <div class="login-title">
                    <h2>Admin Login</h2>
                    <p style="color: var(--text-muted); font-size: 0.9rem; margin-top: 4px;">Masuk menggunakan akun Supabase</p>
                </div>

                <?php if(session()->getFlashdata('error')): ?>
                    <div class="alert-error">
                        <?= esc(session()->getFlashdata('error')) ?>
                    </div>
                <?php endif; ?>

                <form action="/admin/attempt-login" method="POST">
                    <?= csrf_field() ?>
                    <div class="form-group">
                        <label for="email">Email</label>
                        <input type="email" id="email" name="email" required placeholder="admin@example.com" autofocus>
                    </div>
                    <div class="form-group">
                        <label for="password">Password</label>
                        <input type="password" id="password" name="password" required placeholder="••••••••">
                    </div>
                    <button type="submit" class="tm-btn tm-btn-primary btn-login">Login</button>
                </form>
            </div>
        </div>
    </main>
</body>
</html>
