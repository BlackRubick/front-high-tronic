#!/usr/bin/env bash
set -euo pipefail

# deploy.sh
# Script to build the Vite app and deploy to /var/www/facturacion-sieeg
# Usage: sudo ./deploy.sh  (script will use sudo for operations requiring root)

REPO_DIR="/home/ubuntu/front-high-tronic"
NGINX_SRC_CONF="$REPO_DIR/facturacion-sieeg/deploy/nginx-facturacion.sieeg.com.mx.conf"
NGINX_DEST_CONF="/etc/nginx/sites-available/facturacion.sieeg.com.mx.conf"
WWW_DIR="/var/www/facturacion-sieeg"
NODE_VERSION="18"

echo "==> Deploy script starting"

# 1) Ensure running on the expected directory
if [ ! -d "$REPO_DIR" ]; then
  echo "Repo directory $REPO_DIR not found. Adjust REPO_DIR in this script." >&2
  exit 1
fi

# 2) Install nvm if not present (per-user)
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
  echo "Installing nvm..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.6/install.sh | bash
fi

# load nvm
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && \.
"$NVM_DIR/nvm.sh"

# 3) Install Node
echo "Installing Node $NODE_VERSION (via nvm)..."
nvm install $NODE_VERSION
nvm use $NODE_VERSION

# 4) Install dependencies and build
cd "$REPO_DIR"
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi
npm run build

# 5) Copy build to /var/www/facturacion-sieeg
echo "Copying build to $WWW_DIR (requires sudo)..."
sudo rm -rf "$WWW_DIR"
sudo mkdir -p "$WWW_DIR"
sudo cp -r "$REPO_DIR/dist/"* "$WWW_DIR/"
sudo chown -R www-data:www-data "$WWW_DIR"

# 6) Install nginx config
if [ -f "$NGINX_SRC_CONF" ]; then
  echo "Installing nginx config to $NGINX_DEST_CONF"
  sudo cp "$NGINX_SRC_CONF" "$NGINX_DEST_CONF"
  sudo ln -sf "$NGINX_DEST_CONF" /etc/nginx/sites-enabled/facturacion.sieeg.com.mx.conf
fi

# 7) Test and reload nginx
echo "Testing nginx configuration..."
sudo nginx -t
sudo systemctl reload nginx

echo "==> Deploy completed successfully"
