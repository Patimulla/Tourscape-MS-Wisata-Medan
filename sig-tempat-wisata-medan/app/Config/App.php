<?php

namespace Config;

use CodeIgniter\Config\BaseConfig;

class App extends BaseConfig
{
    /**
     * --------------------------------------------------------------------------
     * Base Site URL
     * --------------------------------------------------------------------------
     *
     * URL to your CodeIgniter root. Typically, this will be your base URL,
     * WITH a trailing slash:
     *
     * E.g., http://example.com/
     */
    public string $baseURL = 'http://localhost:8080/';

    /**
     * Allowed Hostnames in the Site URL other than the hostname in the baseURL.
     * If you want to accept multiple Hostnames, set this.
     *
     * E.g.,
     * When your site URL ($baseURL) is 'http://example.com/', and your site
     * also accepts 'http://media.example.com/' and 'http://accounts.example.com/':
     *     ['media.example.com', 'accounts.example.com']
     *
     * @var list<string>
     */
    public array $allowedHostnames = [];

    /**
     * --------------------------------------------------------------------------
     * Index File
     * --------------------------------------------------------------------------
     *
     * Typically, this will be your `index.php` file, unless you've renamed it to
     * something else. If you have configured your web server to remove this file
     * from your site URIs, set this variable to an empty string.
     */
    public string $indexPage = '';

    /**
     * --------------------------------------------------------------------------
     * URI PROTOCOL
     * --------------------------------------------------------------------------
     *
     * This item determines which server global should be used to retrieve the
     * URI string. The default setting of 'REQUEST_URI' works for most servers.
     * If your links do not seem to work, try one of the other delicious flavors:
     *
     *  'REQUEST_URI': Uses $_SERVER['REQUEST_URI']
     * 'QUERY_STRING': Uses $_SERVER['QUERY_STRING']
     *    'PATH_INFO': Uses $_SERVER['PATH_INFO']
     *
     * WARNING: If you set this to 'PATH_INFO', URIs will always be URL-decoded!
     */
    public string $uriProtocol = 'REQUEST_URI';

    /*
    |--------------------------------------------------------------------------
    | Allowed URL Characters
    |--------------------------------------------------------------------------
    |
    | This lets you specify which characters are permitted within your URLs.
    | When someone tries to submit a URL with disallowed characters they will
    | get a warning message.
    |
    | As a security measure you are STRONGLY encouraged to restrict URLs to
    | as few characters as possible.
    |
    | By default, only these are allowed: `a-z 0-9~%.:_-`
    |
    | Set an empty string to allow all characters -- but only if you are insane.
    |
    | The configured value is actually a regular expression character group
    | and it will be used as: '/\A[<permittedURIChars>]+\z/iu'
    |
    | DO NOT CHANGE THIS UNLESS YOU FULLY UNDERSTAND THE REPERCUSSIONS!!
    |
    */
    public string $permittedURIChars = 'a-z 0-9~%.:_\-';

    /**
     * --------------------------------------------------------------------------
     * Default Locale
     * --------------------------------------------------------------------------
     *
     * The Locale roughly represents the language and location that your visitor
     * is viewing the site from. It affects the language strings and other
     * strings (like currency markers, numbers, etc), that your program
     * should run under for this request.
     */
    public string $defaultLocale = 'en';

    /**
     * --------------------------------------------------------------------------
     * Negotiate Locale
     * --------------------------------------------------------------------------
     *
     * If true, the current Request object will automatically determine the
     * language to use based on the value of the Accept-Language header.
     *
     * If false, no automatic detection will be performed.
     */
    public bool $negotiateLocale = false;

    /**
     * --------------------------------------------------------------------------
     * Supported Locales
     * --------------------------------------------------------------------------
     *
     * If $negotiateLocale is true, this array lists the locales supported
     * by the application in descending order of priority. If no match is
     * found, the first locale will be used.
     *
     * IncomingRequest::setLocale() also uses this list.
     *
     * @var list<string>
     */
    public array $supportedLocales = ['en'];

    /**
     * --------------------------------------------------------------------------
     * Application Timezone
     * --------------------------------------------------------------------------
     *
     * The default timezone that will be used in your application to display
     * dates with the date helper, and can be retrieved through app_timezone()
     *
     * @see https://www.php.net/manual/en/timezones.php for list of timezones
     *      supported by PHP.
     */
    public string $appTimezone = 'UTC';

    /**
     * --------------------------------------------------------------------------
     * Default Character Set
     * --------------------------------------------------------------------------
     *
     * This determines which character set is used by default in various methods
     * that require a character set to be provided.
     *
     * @see http://php.net/htmlspecialchars for a list of supported charsets.
     */
    public string $charset = 'UTF-8';

    /**
     * --------------------------------------------------------------------------
     * Force Global Secure Requests
     * --------------------------------------------------------------------------
     *
     * If true, this will force every request made to this application to be
     * made via a secure connection (HTTPS). If the incoming request is not
     * secure, the user will be redirected to a secure version of the page
     * and the HTTP Strict Transport Security (HSTS) header will be set.
     */
    public bool $forceGlobalSecureRequests = false;

    /**
     * --------------------------------------------------------------------------
     * Reverse Proxy IPs
     * --------------------------------------------------------------------------
     *
     * If your server is behind a reverse proxy, you must whitelist the proxy
     * IP addresses from which CodeIgniter should trust headers such as
     * X-Forwarded-For or Client-IP in order to properly identify
     * the visitor's IP address.
     *
     * You need to set a proxy IP address or IP address with subnets and
     * the HTTP header for the client IP address.
     *
     * Here are some examples:
     *     [
     *         '10.0.1.200'     => 'X-Forwarded-For',
     *         '192.168.5.0/24' => 'X-Real-IP',
     *     ]
     *
     * @var array<string, string>
     */
    public array $proxyIPs = [];

    /**
     * --------------------------------------------------------------------------
     * Content Security Policy
     * --------------------------------------------------------------------------
     *
     * Enables the Response's Content Secure Policy to restrict the sources that
     * can be used for images, scripts, CSS files, audio, video, etc. If enabled,
     * the Response object will populate default values for the policy from the
     * `ContentSecurityPolicy.php` file. Controllers can always add to those
     * restrictions at run time.
     *
     * For a better understanding of CSP, see these documents:
     *
     * @see http://www.html5rocks.com/en/tutorials/security/content-security-policy/
     * @see http://www.w3.org/TR/CSP/
     */
    public bool $CSPEnabled = false;

    public function __construct()
    {
        parent::__construct();

        $configuredBaseURL = $this->firstEnvValue([
            'APP_BASE_URL',
            'app.baseURL',
        ], $this->baseURL);

        if ($this->shouldDetectBaseURL($configuredBaseURL)) {
            $configuredBaseURL = $this->detectBaseURLFromRequest() ?? $configuredBaseURL;
        }

        $this->baseURL = $this->normalizeBaseURL($configuredBaseURL);
        $this->indexPage = $this->firstEnvValue([
            'APP_INDEX_PAGE',
            'app.indexPage',
        ], $this->indexPage);
        $this->forceGlobalSecureRequests = $this->envToBool(
            $this->firstEnvValue([
                'APP_FORCE_HTTPS',
                'app.forceGlobalSecureRequests',
            ], $this->forceGlobalSecureRequests)
        );
        $this->appTimezone = $this->firstEnvValue([
            'APP_TIMEZONE',
            'app.appTimezone',
        ], $this->appTimezone);

        $allowedHostnames = $this->firstEnvValue([
            'APP_ALLOWED_HOSTNAMES',
        ], '');

        if ($allowedHostnames !== '') {
            $this->allowedHostnames = array_values(array_filter(array_map(
                static fn(string $hostname): string => trim($hostname),
                explode(',', $allowedHostnames)
            )));
        }
    }

    private function firstEnvValue(array $keys, mixed $default = null): mixed
    {
        foreach ($keys as $key) {
            $value = env($key);

            if ($value !== null && $value !== false && $value !== '') {
                return $value;
            }
        }

        return $default;
    }

    private function envToBool(mixed $value): bool
    {
        if (is_bool($value)) {
            return $value;
        }

        $normalized = strtolower(trim((string) $value));

        return in_array($normalized, ['1', 'true', 'yes', 'on'], true);
    }

    private function normalizeBaseURL(string $baseURL): string
    {
        $baseURL = trim($baseURL);

        if ($baseURL === '') {
            $baseURL = 'http://localhost:8080/';
        }

        return rtrim($baseURL, '/') . '/';
    }

    private function shouldDetectBaseURL(string $configuredBaseURL): bool
    {
        if (is_cli()) {
            return false;
        }

        $trimmed = trim($configuredBaseURL);

        if ($trimmed === '') {
            return true;
        }

        return str_contains($trimmed, 'localhost') || str_contains($trimmed, '127.0.0.1');
    }

    private function detectBaseURLFromRequest(): ?string
    {
        $forwardedProto = $_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '';
        $forwardedHost  = $_SERVER['HTTP_X_FORWARDED_HOST'] ?? '';
        $host           = $forwardedHost !== '' ? $forwardedHost : ($_SERVER['HTTP_HOST'] ?? '');

        if ($host === '') {
            return null;
        }

        $scheme = 'http';

        if ($forwardedProto !== '') {
            $scheme = trim(explode(',', $forwardedProto)[0]);
        } elseif (! empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') {
            $scheme = 'https';
        }

        return sprintf('%s://%s/', $scheme, $host);
    }
}
