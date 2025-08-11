#!/bin/sh
set -e

# Ensure expected writable directories exist before installs
mkdir -p storage/framework/{views,cache,sessions} \
	storage/logs \
	bootstrap/cache

# If vendor exists but not writable (common after host-side chmod), attempt to fix for current user only.
if [ -d vendor ] && [ ! -w vendor ]; then
	echo "[entrypoint] Warning: vendor/ not writable; attempting to adjust permissions for current user." >&2
	chmod u+rwX -R vendor || true
fi

if [ -d node_modules ] && [ ! -w node_modules ]; then
	echo "[entrypoint] Warning: node_modules/ not writable; attempting to adjust permissions for current user." >&2
	chmod u+rwX -R node_modules || true
fi

# Install PHP dependencies (respect already-present vendor to allow faster startup)
if [ ! -f vendor/autoload.php ]; then
	composer install --no-interaction --prefer-dist --optimize-autoloader
else
	composer dump-autoload --optimize
fi

# Install JS dependencies
if [ ! -d node_modules ]; then
	npm install
fi

[ -f .env ] || (cp .env.example .env && php artisan key:generate)

php artisan migrate --force || true
php artisan optimize:clear

# Start Vite dev server (ignore failure to avoid killing PHP-FPM)
if [ -f package.json ]; then
	(npm run dev -- --host 0.0.0.0 || echo "[entrypoint] Vite dev server failed to start" >&2) &
fi

exec php-fpm
