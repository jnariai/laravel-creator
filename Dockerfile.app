FROM php:8.4-fpm-alpine3.21

WORKDIR /usr/share/nginx/html

RUN apk add --no-cache \
    libzip-dev \
    libpng-dev \
    postgresql-client \
    postgresql-dev \
    sqlite-dev \
    mysql-client \
    mariadb-connector-c-dev \
    nodejs \
    npm \
    zip \
    $PHPIZE_DEPS

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN docker-php-ext-install \
    pdo pgsql pdo_pgsql \
    mysqli pdo_mysql \
    pdo_sqlite \
    gd bcmath zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del $PHPIZE_DEPS

COPY . .

RUN chmod -R 755 /usr/share/nginx/html/docker/development/entrypoint.sh

RUN mkdir -p /var/lib/sqlite && \
    chown -R www-data:www-data /var/lib/sqlite && \
    chmod -R 775 /var/lib/sqlite

RUN chown -R 33:33 /var/lib/sqlite

ENTRYPOINT ["/bin/sh", "-c", "./docker/development/entrypoint.sh"]

