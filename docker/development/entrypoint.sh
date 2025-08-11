#!/bin/sh
set -e

composer install --no-interaction --prefer-dist --optimize-autoloader
npm install

[ -f .env ] || (cp .env.example .env && php artisan key:generate)

mkdir -p storage/framework/views
mkdir -p storage/framework/cache
mkdir -p bootstrap/cache

php artisan migrate
php artisan optimize:clear
npm run dev -- --host 0.0.0.0 &
exec php-fpm
