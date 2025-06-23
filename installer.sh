#!/bin/bash

set -e

echo ""
echo "=============================================================="
echo " Welcome to the official Zero Networks script for"
echo " automatically installing the Connect Server"
echo "=============================================================="
echo ""

# -- Function: Install missing package if user agrees --
install_package_if_missing() {
    TOOL="$1"
    if ! command -v "$TOOL" &>/dev/null; then
        echo "[!] '$TOOL' is not installed."

        read -p "    → Would you like to install '$TOOL'? [Y/n] " RESPONSE
        RESPONSE=${RESPONSE,,} # lowercase

        if [[ "$RESPONSE" == "y" || -z "$RESPONSE" ]]; then
            if command -v apt &>/dev/null; then
                sudo apt update && sudo apt install -y "$TOOL"
            elif command -v yum &>/dev/null; then
                sudo yum install -y "$TOOL"
            else
                echo "[ERROR] Unsupported package manager. Please install '$TOOL' manually."
                exit 1
            fi
        else
            echo "[ERROR] '$TOOL' is required to proceed. Exiting."
            exit 1
        fi
    fi
}

# -- Check required tools --
echo "[*] Checking required tools..."
for tool in curl unzip sudo; do
    install_package_if_missing "$tool"
done

# -- Prompt for ZIP URL --
echo ""
read -p "🔗 Enter the Connect Server setup ZIP URL: " SCRIPT_URL

if [[ -z "$SCRIPT_URL" ]]; then
    echo "[ERROR] No URL provided. Exiting."
    exit 1
fi

# -- Prompt for secure token input --
echo ""
read -s -p "🔑 Enter your Zero Networks Connect Server token: " TOKEN
echo ""

if [[ -z "$TOKEN" ]]; then
    echo "[ERROR] No token provided. Exiting."
    exit 1
fi

# -- Prepare temp working directory --
INSTALL_DIR="zero-connect-install-$(date +%s)"
mkdir "$INSTALL_DIR"
cd "$INSTALL_DIR"

# -- Download + unzip setup package --
echo ""
echo "[*] Downloading setup package..."
curl -L -o connect-server.zip "$SCRIPT_URL"

echo "[*] Extracting..."
unzip -q connect-server.zip

SETUP_BIN="./zero-connect-setup"
if [[ ! -f "$SETUP_BIN" ]]; then
    echo "[ERROR] Installer file 'zero-connect-setup' not found after unzip."
    exit 1
fi

chmod +x "$SETUP_BIN"

# -- Run setup with token --
echo "[*] Starting installation..."
sudo "$SETUP_BIN" -token "$TOKEN"

echo ""
echo "✅ Connect Server installation complete."
echo "📁 Installed from: $SCRIPT_URL"
echo ""
