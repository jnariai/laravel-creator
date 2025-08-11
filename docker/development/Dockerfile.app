FROM php:8.4-fpm-alpine3.21

WORKDIR /usr/share/nginx/html

# Allow passing host UID/GID at build time to avoid permission issues with bind mounts.
ARG HOST_UID=1000
ARG HOST_GID=1000

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

RUN mkdir -p /var/lib/sqlite \
    && addgroup -g ${HOST_GID} appgroup \
    && adduser -D -u ${HOST_UID} -G appgroup appuser

USER appuser

COPY . .

ENTRYPOINT ["/bin/sh", "-c", "./docker/development/entrypoint.sh"]
