#!/bin/bash

set -e

SCRIPT_URL=""

# -- Parse arguments for optional --url flag --
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

# -- Cleanup on exit --
TMP_ZIP=""
trap '[[ -f "$TMP_ZIP" ]] && rm -f "$TMP_ZIP"' EXIT

# -- Function: Install missing package automatically --
install_package_if_missing() {
    TOOL="$1"
    if ! command -v "$TOOL" &>/dev/null; then
        echo "[INFO] '$TOOL' not found. Installing..."
        if command -v apt &>/dev/null; then
            sudo apt update -qq && sudo apt install -y "$TOOL"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "$TOOL"
        else
            echo "[ERROR] Unsupported package manager. Please install '$TOOL' manually."
            exit 1
        fi
    fi
}

# -- Tool check --
echo "Checking system requirements..."
for tool in curl unzip sudo; do
    install_package_if_missing "$tool"
done

# -- Check for existing version installation before prompting for URL --
EXISTING_DIR=$(find . -maxdepth 1 -type d -name 'zero-connect-server-setup-*' | sort | tail -n 1)
if [[ -n "$EXISTING_DIR" && -f "$EXISTING_DIR"/zero-connect-setup ]]; then
    VERSION_GUESS=$(echo "$EXISTING_DIR" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    echo ""
    echo "Found previously installed version: $VERSION_GUESS at $EXISTING_DIR"
    read -p "(U)pdate with new URL, (S)kip download and re-run install, or (E)xit? [U/s/e]: " EXISTING_ACTION
    EXISTING_ACTION=${EXISTING_ACTION,,}

    if [[ "$EXISTING_ACTION" == "s" ]]; then
        INSTALL_DIR="$EXISTING_DIR"
        SKIP_DOWNLOAD=true
    elif [[ "$EXISTING_ACTION" == "e" ]]; then
        echo "Exiting installer."
        exit 0
    else
        SKIP_DOWNLOAD=false
        echo "Proceeding with new package download."
    fi
else
    SKIP_DOWNLOAD=false
fi

# -- Prompt for URL if not provided via --url --
if [[ "$SKIP_DOWNLOAD" != true ]]; then
    if [[ -z "$SCRIPT_URL" ]]; then
        echo ""
        read -p "Enter the Connect Server ZIP package URL: " SCRIPT_URL
        if [[ -z "$SCRIPT_URL" ]]; then
            echo "[ERROR] No URL provided. Aborting."
            exit 1
        fi
    fi

    VERSION=$(echo "$SCRIPT_URL" | grep -oP 'zero-connect-server-setup-\K[0-9\.]+')
    INSTALL_DIR="zero-connect-server-setup-$VERSION"

    if [[ -d "$INSTALL_DIR" ]]; then
        echo ""
        echo "Detected existing folder for version '$VERSION': $INSTALL_DIR"
        echo "Cleaning directory to prepare for fresh installation."
        rm -rf "$INSTALL_DIR"
    fi

    mkdir -p "$INSTALL_DIR"
    echo "Downloading and extracting package..."
    TMP_ZIP=$(mktemp)
    curl -sSL "$SCRIPT_URL" -o "$TMP_ZIP"
    unzip -q "$TMP_ZIP" -d "$INSTALL_DIR"
    rm -f "$TMP_ZIP"
fi

# -- Prompt for token if not set via env var --
if [[ -z "$ZNC_TOKEN" ]]; then
    while true; do
        echo ""
        read -s -p "Enter your Zero Networks Connect Server token (input hidden): " TOKEN
        echo ""

        if [[ -z "$TOKEN" ]]; then
            echo "Token is blank. Please try again."
        elif [[ "$TOKEN" =~ \  ]]; then
            echo "Token contains spaces. Check for copy-paste issues."
        elif [[ ${#TOKEN} -lt 400 ]]; then
            echo "Token appears incomplete. Please verify."
        else
            break
        fi
    done
else
    TOKEN="$ZNC_TOKEN"
    echo "Using token from environment variable ZNC_TOKEN."
fi

# -- Find and run the installer --
SETUP_BIN=$(find "$INSTALL_DIR" -type f -name "zero-connect-setup" | head -n 1)
if [[ -z "$SETUP_BIN" || ! -f "$SETUP_BIN" ]]; then
    echo "[ERROR] Installer executable not found."
    exit 1
fi

chmod +x "$SETUP_BIN"

# -- Save token to file and export variable --
TOKEN_FILE="$(dirname "$SETUP_BIN")/token"
echo "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "[ERROR] Failed to write token file."
    exit 1
fi

# -- Move to install directory and execute setup properly --
INSTALL_ROOT="$(dirname "$SETUP_BIN")"
cd "$INSTALL_ROOT" || {
    echo "[ERROR] Failed to change directory to $INSTALL_ROOT"
    exit 1
}

[[ -f "zero-connect-setup" ]] || { echo "[ERROR] zero-connect-setup missing."; exit 1; }
[[ -f "token" ]] || { echo "[ERROR] token file missing."; exit 1; }
[[ -d "dependencies" ]] || echo "[WARNING] 'dependencies/' directory not found. Installer may fail."

token=$(<token)

echo ""
echo "Launching Connect Server installer..."
echo "Running: ./zero-connect-setup"
echo "Token preview: ${token:0:20}...[redacted]"
sleep 1

sudo --preserve-env=token ./zero-connect-setup -token "$token"

# -- Clean up token --
rm -f token
