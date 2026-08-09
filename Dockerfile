FROM node:22-bookworm-slim AS assets

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY resources ./resources
COPY public ./public
COPY vite.config.ts ./
COPY tsconfig.json ./
COPY components.json ./
COPY eslint.config.js ./

RUN npm run build

FROM php:8.3-apache-bookworm AS app

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libicu-dev \
        libpq-dev \
        libzip-dev \
        zip \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        intl \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        zip \
    && a2enmod headers rewrite expires remoteip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY docker/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY docker/php/conf.d/opcache.ini /usr/local/etc/php/conf.d/99-opcache.ini
COPY docker/php/entrypoint.sh /usr/local/bin/app-entrypoint

RUN chmod +x /usr/local/bin/app-entrypoint

COPY composer.json composer.lock ./
COPY package.json package-lock.json ./
COPY artisan ./
COPY app ./app
COPY bootstrap ./bootstrap
COPY config ./config
COPY database ./database
COPY public ./public
COPY resources ./resources
COPY routes ./routes
COPY storage ./storage
COPY vite.config.ts ./

RUN composer install \
        --no-dev \
        --no-interaction \
        --no-progress \
        --prefer-dist \
        --optimize-autoloader

COPY --from=assets /app/public/build ./public/build

RUN chown -R www-data:www-data /var/www/html \
    && find storage bootstrap/cache -type d -exec chmod 775 {} \; \
    && find storage bootstrap/cache -type f -exec chmod 664 {} \;

ENTRYPOINT ["app-entrypoint"]
CMD ["apache2-foreground"]

