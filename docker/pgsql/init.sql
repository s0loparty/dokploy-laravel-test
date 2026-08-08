-- docker/pgsql/init.sql
-- Создание базы данных если не существует
CREATE DATABASE laravel;

-- Настройка прав доступа
GRANT ALL PRIVILEGES ON DATABASE laravel TO sail;

-- Подключение к базе laravel
\c laravel;

-- Дополнительные настройки
ALTER SCHEMA public OWNER TO sail;
GRANT ALL ON SCHEMA public TO sail;
GRANT ALL ON ALL TABLES IN SCHEMA public TO sail;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO sail;
