#!/bin/bash

set -e

SCRIPT_URL=""

# -- Parse arguments --
while [[ $# -gt 0 ]]; do
  case $1 in
    --url)
      SCRIPT_URL="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo ""
echo "=============================================================="
echo " Zero Networks Connect Server Installation Script"
echo "=============================================================="
echo ""

TMP_ZIP=""
trap '[[ -f "$TMP_ZIP" ]] && rm -f "$TMP_ZIP"' EXIT

install_package_if_missing() {
    TOOL="$1"
    if ! command -v "$TOOL" &>/dev/null; then
        echo "[INFO] Installing missing package: $TOOL"
        if command -v apt &>/dev/null; then
            sudo apt update -qq && sudo apt install -y "$TOOL"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "$TOOL"
        else
            echo "[ERROR] Unsupported package manager. Install $TOOL manually."
            exit 1
        fi
    fi
}

echo "Checking system requirements..."
for tool in curl unzip sudo; do
    install_package_if_missing "$tool"
done

EXISTING_DIR=$(find . -maxdepth 1 -type d -name 'zero-connect-server-setup-*' | sort | tail -n 1)
if [[ -n "$EXISTING_DIR" && -f "$EXISTING_DIR/zero-connect-setup" ]]; then
    VERSION_GUESS=$(echo "$EXISTING_DIR" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    echo ""
    echo "Found previously installed version: $VERSION_GUESS at $EXISTING_DIR"
    read -p "(U)pdate with new URL, (S)kip download and re-run install, or (E)xit? [U/s/e]: " EXISTING_ACTION
    EXISTING_ACTION=${EXISTING_ACTION,,}

    if [[ "$EXISTING_ACTION" == "s" ]]; then
        INSTALL_DIR="$EXISTING_DIR"
        SKIP_DOWNLOAD=true
    elif [[ "$EXISTING_ACTION" == "e" ]]; then
        echo "Exiting."
        exit 0
    else
        SKIP_DOWNLOAD=false
    fi
else
    SKIP_DOWNLOAD=false
fi

if [[ "$SKIP_DOWNLOAD" != true ]]; then
    if [[ -z "$SCRIPT_URL" ]]; then
        echo ""
        read -p "Enter the Connect Server ZIP package URL: " SCRIPT_URL
        if [[ -z "$SCRIPT_URL" ]]; then
            echo "[ERROR] No URL provided."
            exit 1
        fi
    fi

    VERSION=$(echo "$SCRIPT_URL" | grep -oP 'zero-connect-server-setup-\K[0-9\.]+')
    INSTALL_DIR="zero-connect-server-setup-$VERSION"

    if [[ -d "$INSTALL_DIR" ]]; then
        echo ""
        echo "Detected existing folder: $INSTALL_DIR"
        echo "Cleaning it for fresh install."
        rm -rf "$INSTALL_DIR"
    fi

    mkdir -p "$INSTALL_DIR"
    echo "Downloading and extracting package..."
    TMP_ZIP=$(mktemp)
    curl -sSL "$SCRIPT_URL" -o "$TMP_ZIP"
    unzip -q "$TMP_ZIP" -d "$INSTALL_DIR"
    rm -f "$TMP_ZIP"
fi

# -- Token input --
if [[ -z "$ZNC_TOKEN" ]]; then
    while true; do
        echo ""
        read -s -p "Enter your Zero Networks Connect Server token (input hidden): " TOKEN
        echo ""
        if [[ -z "$TOKEN" ]]; then
            echo "Token is blank. Try again."
        elif [[ "$TOKEN" =~ \  ]]; then
            echo "Token has spaces. Fix copy-paste."
        elif [[ ${#TOKEN} -lt 400 ]]; then
            echo "Token seems too short. Verify it."
        else
            break
        fi
    done
else
    TOKEN="$ZNC_TOKEN"
    echo "Using token from env var ZNC_TOKEN."
fi

SETUP_BIN=$(find "$INSTALL_DIR" -type f -name "zero-connect-setup" | head -n 1)
if [[ -z "$SETUP_BIN" || ! -f "$SETUP_BIN" ]]; then
    echo "[ERROR] Installer executable not found in $INSTALL_DIR."
    exit 1
fi

chmod +x "$SETUP_BIN"

# -- Save token to file --
TOKEN_FILE="$(dirname "$SETUP_BIN")/token"
echo "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "[ERROR] Failed to write token."
    exit 1
fi

INSTALL_ROOT="$(dirname "$SETUP_BIN")"
cd "$INSTALL_ROOT" || {
    echo "[ERROR] Could not cd to $INSTALL_ROOT"
    exit 1
}

[[ -f "zero-connect-setup" ]] || { echo "[ERROR] zero-connect-setup missing."; exit 1; }
[[ -f "token" ]] || { echo "[ERROR] token file missing."; exit 1; }

echo ""
echo "Launching Connect Server installer..."
echo "Running: ./zero-connect-setup"
echo "Token preview: ${TOKEN:0:20}...[redacted]"
sleep 1

# Run with sudo and token
sudo ./zero-connect-setup -token "$TOKEN"

# Clean up
rm -f token
