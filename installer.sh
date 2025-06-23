#!/bin/bash

set -e

echo ""
echo "=============================================================="
echo " Welcome to the official Zero Networks script for"
echo " automatically installing the Connect Server"
echo "=============================================================="
echo ""

# -- Cleanup on exit --
TMP_ZIP=""
trap '[[ -f "$TMP_ZIP" ]] && rm -f "$TMP_ZIP"' EXIT

# -- Function: Install missing package if user agrees --
install_package_if_missing() {
    TOOL="$1"
    if ! command -v "$TOOL" &>/dev/null; then
        echo ""
        echo "'$TOOL' is not installed."
        read -p "Would you like to install '$TOOL'? [Y/n] " RESPONSE
        RESPONSE=${RESPONSE,,}
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

# -- Tool check --
echo "Checking required tools..."
for tool in curl unzip sudo; do
    install_package_if_missing "$tool"
done

# -- Prompt for URL --
echo ""
read -p "Enter the Connect Server setup ZIP URL: " SCRIPT_URL
if [[ -z "$SCRIPT_URL" ]]; then
    echo "[ERROR] No URL provided. Exiting."
    exit 1
fi

# -- Extract version and determine install dir --
VERSION=$(echo "$SCRIPT_URL" | grep -oP 'zero-connect-server-setup-\K[0-9\.]+')
BASE_DIR="zero-connect-install-$VERSION"
INSTALL_DIR="$BASE_DIR"

# -- Check for existing installation before token prompt --
if [[ -d "$INSTALL_DIR" ]]; then
    echo ""
    echo "We detected version '$VERSION' is already downloaded in: $INSTALL_DIR"
    read -p "Would you like to (R)edownload, (S)kip download and run install, or (E)xit? [R/s/e]: " ACTION
    ACTION=${ACTION,,}

    if [[ "$ACTION" == "s" ]]; then
        echo "Skipping download. Using existing files in $INSTALL_DIR."
        SKIP_DOWNLOAD=true
    elif [[ "$ACTION" == "e" ]]; then
        echo "Exiting."
        exit 0
    else
        echo "Redownloading. Cleaning up existing directory..."
        rm -rf "$INSTALL_DIR"
        mkdir -p "$INSTALL_DIR"
        SKIP_DOWNLOAD=false
    fi
else
    mkdir -p "$INSTALL_DIR"
    SKIP_DOWNLOAD=false
fi

# -- Prompt for token with validation loop --
while true; do
    echo ""
    read -s -p "Enter your Zero Networks Connect Server token (input hidden): " TOKEN
    echo ""

    if [[ -z "$TOKEN" ]]; then
        echo "Token is blank. Please try again."
    elif [[ "$TOKEN" =~ \  ]]; then
        echo "Token contains spaces. Check for copy-paste errors."
    elif [[ ${#TOKEN} -lt 400 ]]; then
        echo "Token looks too short. Check that it's complete."
    else
        break
    fi
done

# -- Download and extract ZIP --
if [[ "$SKIP_DOWNLOAD" != true ]]; then
    echo ""
    echo "Downloading and extracting package..."
    TMP_ZIP=$(mktemp)
    curl -sSL "$SCRIPT_URL" -o "$TMP_ZIP"
    unzip -q "$TMP_ZIP" -d "$INSTALL_DIR"
    rm -f "$TMP_ZIP"
fi

# -- Find and run the installer --
SETUP_BIN=$(find "$INSTALL_DIR" -type f -name "zero-connect-setup" | head -n 1)
if [[ -z "$SETUP_BIN" || ! -f "$SETUP_BIN" ]]; then
    echo "[ERROR] Installer file 'zero-connect-setup' not found after unzip."
    exit 1
fi

chmod +x "$SETUP_BIN"

# -- Save token to file with secure permissions --
TOKEN_FILE="$(dirname "$SETUP_BIN")/token"
echo "$TOKEN" | sudo tee "$TOKEN_FILE" > /dev/null
sudo chmod 600 "$TOKEN_FILE"

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "[ERROR] Failed to save token to: $TOKEN_FILE"
    exit 1
fi

echo ""
echo "Running the installer from: $SETUP_BIN"
sleep 1
sudo "$SETUP_BIN" -token "$(cat "$TOKEN_FILE")"

# -- Optional: Clean up token file after install --
# sudo rm -f "$TOKEN_FILE"

echo ""
echo "Connect Server installation complete."
echo "Installed from: $SCRIPT_URL"
echo ""
