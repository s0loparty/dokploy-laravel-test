#!/usr/bin/env sh
set -eu

APP_ROLE="${APP_ROLE:-app}"

prepare_storage() {
    mkdir -p \
        bootstrap/cache \
        storage/app/public \
        storage/framework/cache/data \
        storage/framework/sessions \
        storage/framework/testing \
        storage/framework/views \
        storage/logs

    chown -R www-data:www-data storage bootstrap/cache
    chmod -R ug+rwx storage bootstrap/cache
}

wait_for_database() {
    if [ "${DB_CONNECTION:-sqlite}" = "sqlite" ]; then
        return 0
    fi

    echo "Waiting for database connection..."

    attempts=0
    until php -r '
        $driver = getenv("DB_CONNECTION") ?: "pgsql";
        $database = getenv("DB_DATABASE") ?: "laravel";

        if ($driver === "sqlite") {
            $path = $database === ":memory:" ? ":memory:" : $database;
            new PDO("sqlite:" . $path);
            exit(0);
        }

        $host = getenv("DB_HOST") ?: "127.0.0.1";
        $port = getenv("DB_PORT") ?: ($driver === "pgsql" ? "5432" : "3306");
        $username = getenv("DB_USERNAME") ?: "root";
        $password = getenv("DB_PASSWORD") ?: "";

        $dsn = match ($driver) {
            "pgsql" => "pgsql:host={$host};port={$port};dbname={$database}",
            "mysql", "mariadb" => "mysql:host={$host};port={$port};dbname={$database}",
            default => throw new RuntimeException("Unsupported DB_CONNECTION [{$driver}] for container startup."),
        };

        new PDO($dsn, $username, $password, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    ' >/dev/null 2>&1; do
        attempts=$((attempts + 1))

        if [ "$attempts" -ge 30 ]; then
            echo "Database did not become ready after ${attempts} attempts." >&2
            exit 1
        fi

        sleep 2
    done
}

warm_application() {
    php artisan optimize:clear --ansi
    php artisan migrate --force --ansi
    php artisan storage:link --ansi || true
    php artisan optimize --ansi
}

prepare_storage
wait_for_database

if [ "$APP_ROLE" = "app" ]; then
    warm_application
fi

exec "$@"

