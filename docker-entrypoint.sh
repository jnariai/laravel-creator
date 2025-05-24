#!/bin/sh
set -e

export PATH="/root/.composer/vendor/bin:$PATH"

if ! which laravel >/dev/null; then
    echo "ERROR: Laravel installer not found in PATH"
    echo "PATH=$PATH"
    exit 1
fi

if [ ! -x "$(which laravel)" ]; then
    echo "ERROR: Laravel installer found but not executable"
    echo "Fixing permissions..."
    chmod +x "$(which laravel)"
fi

exec "$@"