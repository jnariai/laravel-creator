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

RUN mkdir -p /var/lib/sqlite
RUN addgroup -g 1000 appgroup && adduser -D -u 1000 -G appgroup appuser
USER appuser
COPY . .

ENTRYPOINT ["/bin/sh", "-c", "./docker/development/entrypoint.sh"]
