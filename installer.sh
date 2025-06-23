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

# -- Extract version and determine install dir --
VERSION=$(echo "$SCRIPT_URL" | grep -oP 'zero-connect-server-setup-\K[0-9\.]+')
BASE_DIR="zero-connect-install-$VERSION"
INSTALL_DIR="$BASE_DIR"

# -- Handle duplicate folder names --
if [[ -d "$BASE_DIR" ]]; then
    echo ""
    echo "Directory '$BASE_DIR' already exists."
    read -p "Would you like to (O)verwrite or (C)reate a new folder? [O/c]: " DIR_CHOICE
    DIR_CHOICE=${DIR_CHOICE,,}

    if [[ "$DIR_CHOICE" == "c" ]]; then
        SUFFIX=1
        while [[ -d "${BASE_DIR}-${SUFFIX}" ]]; do
            ((SUFFIX++))
        done
        INSTALL_DIR="${BASE_DIR}-${SUFFIX}"
    else
        rm -rf "$BASE_DIR"
    fi
fi

mkdir -p "$INSTALL_DIR"

# -- Download ZIP to temp file and extract into install dir --
echo ""
echo "Downloading and extracting package..."
TMP_ZIP=$(mktemp)
curl -sSL "$SCRIPT_URL" -o "$TMP_ZIP"
unzip -q "$TMP_ZIP" -d "$INSTALL_DIR"
rm -f "$TMP_ZIP"

# -- Find and run the installer --
SETUP_BIN=$(find "$INSTALL_DIR" -type f -name "zero-connect-setup" | head -n 1)
if [[ -z "$SETUP_BIN" || ! -f "$SETUP_BIN" ]]; then
    echo "[ERROR] Installer file 'zero-connect-setup' not found after unzip."
    exit 1
fi

chmod +x "$SETUP_BIN"

echo ""
echo "Running the installer from: $SETUP_BIN"
sleep 1
# Save the token to a file in the setup directory
TOKEN_FILE="$(dirname "$SETUP_BIN")/token"
echo "$TOKEN" > "$TOKEN_FILE"

# Run the installer using the token file
sudo "$SETUP_BIN" -token "$(cat "$TOKEN_FILE")"

echo ""
echo "Connect Server installation complete."
echo "Installed from: $SCRIPT_URL"
