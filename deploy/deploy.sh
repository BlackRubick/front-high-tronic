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

# Determine the real user (handle running via sudo)
TARGET_USER="${SUDO_USER:-$(whoami)}"
USER_HOME="$(eval echo ~${TARGET_USER})"

# load or install nvm into the target user's home
export NVM_DIR="$USER_HOME/.nvm"
# shellcheck source=/dev/null
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # source nvm so we can use it in this script
  . "$NVM_DIR/nvm.sh"
else
  echo "nvm not found in $NVM_DIR — installing nvm for user $TARGET_USER"
  # install nvm as the target user so it lands in their home
  sudo -u "$TARGET_USER" bash -lc "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.6/install.sh | bash"
  # source after install (install creates nvm.sh in the user's home)
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
  else
    echo "Failed to install or find nvm at $NVM_DIR/nvm.sh" >&2
    exit 1
  fi
fi

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
