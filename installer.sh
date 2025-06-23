#!/bin/bash

set -e

SCRIPT_URL=""

# --- Parse arguments ---
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

# --- Cleanup on exit ---
TMP_ZIP=""
trap '[[ -f "$TMP_ZIP" ]] && rm -f "$TMP_ZIP"' EXIT

# --- Function to auto-install missing tools ---
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

# --- Tool check ---
echo "Checking system requirements..."
for tool in curl unzip sudo; do
  install_package_if_missing "$tool"
done

# --- Check for existing installation ---
EXISTING_DIR=$(find . -maxdepth 1 -type d -name 'zero-connect-server-setup-*' | sort | tail -n 1)
if [[ -n "$EXISTING_DIR" && -f "$EXISTING_DIR/zero-connect-setup" ]]; then
  VERSION_GUESS=$(echo "$EXISTING_DIR" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || true)
  echo ""
  echo "Found existing install: $VERSION_GUESS at $EXISTING_DIR"
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

# --- Prompt for URL if needed ---
if [[ "$SKIP_DOWNLOAD" != true ]]; then
  if [[ -z "$SCRIPT_URL" ]]; then
    echo ""
    read -p "Enter the Connect Server ZIP package URL: " SCRIPT_URL
    if [[ -z "$SCRIPT_URL" ]]; then
      echo "[ERROR] No URL provided. Aborting."
      exit 1
    fi
  fi

  # Extract and sanitize version
  VERSION=$(echo "$SCRIPT_URL" | grep -oP 'zero-connect-server-setup-\K[0-9\.]+' | sed 's/\.*$//')
  INSTALL_BASE="zero-connect-install-$VERSION"
  INSTALL_DIR="$INSTALL_BASE"

  if [[ -d "$INSTALL_DIR" ]]; then
    echo ""
    echo "Cleaning existing install folder: $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
  fi

  mkdir -p "$INSTALL_DIR"
  TMP_ZIP=$(mktemp)
  echo "Downloading package..."
  curl -sSL "$SCRIPT_URL" -o "$TMP_ZIP"

  echo "Extracting package..."
  unzip -q "$TMP_ZIP" -d "$INSTALL_DIR"
  rm -f "$TMP_ZIP"

  # Check for nested folder inside ZIP
  INNER_DIR=$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type d -name 'zero-connect-server-setup-*' | head -n 1)
  if [[ -n "$INNER_DIR" ]]; then
    INSTALL_DIR="$INNER_DIR"
  fi
fi

# --- Prompt for token ---
if [[ -z "$ZNC_TOKEN" ]]; then
  while true; do
    echo ""
    read -s -p "Enter your Zero Networks Connect Server token (input hidden): " TOKEN
    echo ""
    if [[ -z "$TOKEN" ]]; then
      echo "Token is blank. Try again."
    elif [[ "$TOKEN" =~ \  ]]; then
      echo "Token contains spaces. Please fix copy-paste."
    elif [[ ${#TOKEN} -lt 400 ]]; then
      echo "Token looks incomplete. Please verify."
    else
      break
    fi
  done
else
  TOKEN="$ZNC_TOKEN"
  echo "Using token from environment variable ZNC_TOKEN."
fi

# --- Find and validate installer binary ---
SETUP_BIN=$(find "$INSTALL_DIR" -type f -name "zero-connect-setup" | head -n 1)
if [[ -z "$SETUP_BIN" || ! -f "$SETUP_BIN" ]]; then
  echo "[ERROR] Installer binary not found."
  exit 1
fi

chmod +x "$SETUP_BIN"
INSTALL_ROOT="$(dirname "$SETUP_BIN")"

# Save token
TOKEN_FILE="$INSTALL_ROOT/token"
echo "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

# --- Final check ---
echo ""
echo "Launching Connect Server installer..."
echo "[DEBUG] SETUP_BIN=$SETUP_BIN"
echo "[DEBUG] INSTALL_ROOT=$INSTALL_ROOT"
echo "Running: ./zero-connect-setup"
echo "Token preview: ${TOKEN:0:20}...[redacted]"
sleep 1

cd "$INSTALL_ROOT"
sudo ./zero-connect-setup -token "$TOKEN"

# Cleanup
rm -f token
