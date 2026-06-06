<?php

/**
 * The goal of this file is to allow developers a location
 * where they can overwrite core procedural functions and
 * replace them with their own. This file is loaded during
 * the bootstrap process and is called during the framework's
 * execution.
 *
 * This can be looked at as a `master helper` file that is
 * loaded early on, and may also contain additional functions
 * that you'd like to use throughout your entire application
 *
 * @see: https://codeigniter.com/user_guide/extending/common.html
 */

if (! function_exists('app_env')) {
    /**
     * Read environment variables from the usual CI/PHP sources first,
     * then fall back to Linux process environment files when Apache/PHP
     * does not expose Railway variables through $_ENV/$_SERVER/getenv.
     */
    function app_env(string $key, mixed $default = null): mixed
    {
        $value = $_ENV[$key] ?? $_SERVER[$key] ?? getenv($key);

        if ($value !== false && $value !== null && $value !== '') {
            return app_env_normalize($value);
        }

        if (function_exists('apache_getenv')) {
            $apacheValue = apache_getenv($key, true);

            if ($apacheValue !== false && $apacheValue !== null && $apacheValue !== '') {
                return app_env_normalize($apacheValue);
            }
        }

        foreach (app_env_process_maps() as $map) {
            if (array_key_exists($key, $map) && $map[$key] !== '') {
                return app_env_normalize($map[$key]);
            }
        }

        return $default;
    }
}

if (! function_exists('app_env_process_maps')) {
    function app_env_process_maps(): array
    {
        static $maps;

        if ($maps !== null) {
            return $maps;
        }

        $maps = [
            app_env_parse_proc('/proc/self/environ'),
            app_env_parse_proc('/proc/1/environ'),
        ];

        return $maps;
    }
}

if (! function_exists('app_env_parse_proc')) {
    function app_env_parse_proc(string $path): array
    {
        if (!is_readable($path)) {
            return [];
        }

        $raw = @file_get_contents($path);

        if ($raw === false || $raw === '') {
            return [];
        }

        $result = [];

        foreach (explode("\0", $raw) as $pair) {
            if ($pair === '' || !str_contains($pair, '=')) {
                continue;
            }

            [$k, $v] = explode('=', $pair, 2);
            $result[$k] = $v;
        }

        return $result;
    }
}

if (! function_exists('app_env_normalize')) {
    function app_env_normalize(mixed $value): mixed
    {
        if (! is_string($value)) {
            return $value;
        }

        return match (strtolower($value)) {
            'true'  => true,
            'false' => false,
            'empty' => '',
            'null'  => null,
            default => $value,
        };
    }
}
