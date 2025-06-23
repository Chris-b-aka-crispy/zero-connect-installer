#!/bin/bash

set -e

echo ""
echo "=============================================================="
echo " Welcome to the official Zero Networks script for"
echo " automatically installing the Connect Server"
echo "=============================================================="
echo ""

# Check required tools
for tool in curl unzip; do
    if ! command -v $tool &>/dev/null; then
        echo "[ERROR] Required tool '$tool' is not installed."
        echo "        Please install it and re-run this script."
        exit 1
    fi
done

# Prompt for the download URL
echo ""
read -p "🔗 Enter the Connect Server setup ZIP URL: " SCRIPT_URL

if [[ -z "$SCRIPT_URL" ]]; then
    echo "[ERROR] No URL provided. Exiting."
    exit 1
fi

# Prompt for the token securely
echo ""
read -s -p "Enter your Zero Networks Connect Server token: " TOKEN
echo ""

if [[ -z "$TOKEN" ]]; then
    echo "[ERROR] No token provided. Exiting."
    exit 1
fi

# Create temp folder
INSTALL_DIR="zero-connect-install-$(date +%s)"
mkdir "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Download and extract
echo ""
echo "[*] Downloading setup package..."
curl -L -o connect-server.zip "$SCRIPT_URL"

echo "[*] Extracting..."
unzip -q connect-server.zip

# Locate the setup binary
SETUP_BIN="./zero-connect-setup"
if [[ ! -f "$SETUP_BIN" ]]; then
    echo "[ERROR] Installer file 'zero-connect-setup' not found after unzip."
    exit 1
fi

chmod +x "$SETUP_BIN"

# Run the installer with token
echo "[*] Starting installation..."
sudo "$SETUP_BIN" -token "$TOKEN"

echo ""
echo "Connect Server installation complete."
echo "Installed from: $SCRIPT_URL"
echo ""
