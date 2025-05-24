#!/bin/sh

composer install
npm install

if [ ! -f .env ]; then
    cp .env.example .env
    php artisan key:generate
fi

if [ ! -d storage/framework/views ]; then
    mkdir -p storage/framework/views
    chmod -R 775 storage/framework/views
fi


php artisan migrate &
php artisan optimize:clear &
npm run dev -- --host 0.0.0.0 &
php-fpm