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
echo " Welcome to the official Zero Networks script for"
echo " automatically installing the Connect Server"
echo "=============================================================="
echo ""

# -- Cleanup on exit --
TMP_ZIP=""
trap '[[ -f "$TMP_ZIP" ]] && rm -f "$TMP_ZIP"' EXIT

# -- Function: Install missing package automatically --
install_package_if_missing() {
    TOOL="$1"
    if ! command -v "$TOOL" &>/dev/null; then
        echo "'$TOOL' is not installed. Installing..."
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y "$TOOL"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "$TOOL"
        else
            echo "[ERROR] Unsupported package manager. Please install '$TOOL' manually."
            exit 1
        fi
    fi
}

# -- Tool check --
echo "Checking required tools..."
for tool in curl unzip sudo; do
    install_package_if_missing "$tool"
done

# -- Check for existing version installation before prompting for URL --
EXISTING_DIR=$(find . -maxdepth 1 -type d -name 'zero-connect-server-setup-*' | sort | tail -n 1)
if [[ -n "$EXISTING_DIR" && -f "$EXISTING_DIR"/zero-connect-setup ]]; then
    VERSION_GUESS=$(echo "$EXISTING_DIR" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
    echo ""
    echo "Detected existing installed version at: $EXISTING_DIR"
    read -p "Would you like to (U)pdate with new URL, (S)kip download and re-run install, or (E)xit? [U/s/e]: " EXISTING_ACTION
    EXISTING_ACTION=${EXISTING_ACTION,,}

    if [[ "$EXISTING_ACTION" == "s" ]]; then
        INSTALL_DIR="$EXISTING_DIR"
        SKIP_DOWNLOAD=true
    elif [[ "$EXISTING_ACTION" == "e" ]]; then
        echo "Exiting."
        exit 0
    else
        SKIP_DOWNLOAD=false
        echo "Proceeding to use new URL..."
    fi
else
    SKIP_DOWNLOAD=false
fi

# -- Prompt for URL only if not passed in or skipping not chosen --
if [[ "$SKIP_DOWNLOAD" != true ]]; then
    if [[ -z "$SCRIPT_URL" ]]; then
        echo ""
        read -p "Enter the Connect Server setup ZIP URL: " SCRIPT_URL
        if [[ -z "$SCRIPT_URL" ]]; then
            echo "[ERROR] No URL provided. Exiting."
            exit 1
        fi
    fi

    VERSION=$(echo "$SCRIPT_URL" | grep -oP 'zero-connect-server-setup-\K[0-9\.]+')
    INSTALL_DIR="zero-connect-server-setup-$VERSION"

    if [[ -d "$INSTALL_DIR" ]]; then
        echo ""
        echo "We detected version '$VERSION' is already downloaded in: $INSTALL_DIR"
        echo "Cleaning up existing directory for fresh install..."
        rm -rf "$INSTALL_DIR"
    fi

    mkdir -p "$INSTALL_DIR"
    echo "Downloading and extracting package..."
    TMP_ZIP=$(mktemp)
    curl -sSL "$SCRIPT_URL" -o "$TMP_ZIP"
    unzip -q "$TMP_ZIP" -d "$INSTALL_DIR"
    rm -f "$TMP_ZIP"
fi

# -- Prompt for token only if not set via env var --
if [[ -z "$ZNC_TOKEN" ]]; then
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
else
  TOKEN="$ZNC_TOKEN"
  echo "Using token from ZNC_TOKEN environment variable."
fi

# -- Find and run the installer --
SETUP_BIN=$(find "$INSTALL_DIR" -type f -name "zero-connect-setup" | head -n 1)
if [[ -z "$SETUP_BIN" || ! -f "$SETUP_BIN" ]]; then
    echo "[ERROR] Installer file 'zero-connect-setup' not found after unzip."
    exit 1
fi

chmod +x "$SETUP_BIN"

# -- Save token to file and export as shell variable --
TOKEN_FILE="$(dirname "$SETUP_BIN")/token"
echo "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "[ERROR] Failed to save token to: $TOKEN_FILE"
    exit 1
fi

# -- Export and run installer with correct flag --
cd "$(dirname "$SETUP_BIN")"
token=$(cat token)

echo ""
echo "Running the installer from: $SETUP_BIN"
echo "Passing token to installer: ${token:0:20}...[redacted]"
sleep 1
sudo ./zero-connect-setup -token "$token"

# -- Optional: Clean up token file after install --
rm -f token

echo ""
echo "Connect Server installation complete."
echo "Installed from: ${SCRIPT_URL:-"(skipped)"}"
echo "Follow the on-screen prompts to complete setup."
echo ""
