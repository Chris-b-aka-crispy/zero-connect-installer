#!/bin/bash

set -e

SCRIPT_URL=""
TMP_ZIP=""
TOKEN=""
INSTALL_DIR=""

trap '[[ -f "$TMP_ZIP" ]] && rm -f "$TMP_ZIP"' EXIT

# --- Parse CLI arguments ---
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

# --- Requirements ---
for tool in curl unzip sudo; do
  if ! command -v "$tool" &>/dev/null; then
    echo "[ERROR] Missing required tool: $tool"
    exit 1
  fi
done

# --- Ask for URL if not provided ---
if [[ -z "$SCRIPT_URL" ]]; then
  echo ""
  read -p "Enter the Connect Server ZIP package URL: " SCRIPT_URL
  [[ -z "$SCRIPT_URL" ]] && { echo "[ERROR] No URL provided."; exit 1; }
fi

# --- Sanitize version from URL ---
VERSION=$(echo "$SCRIPT_URL" | grep -oP 'zero-connect-server-setup-\K[0-9\.]+' | sed 's/\.*$//')
INSTALL_BASE="zero-connect-install-$VERSION"
INSTALL_DIR="$INSTALL_BASE"

# --- Clean if exists ---
[[ -d "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# --- Download + unzip ---
TMP_ZIP=$(mktemp)
echo "Downloading package..."
curl -sSL "$SCRIPT_URL" -o "$TMP_ZIP"

echo "Extracting..."
unzip -q "$TMP_ZIP" -d "$INSTALL_DIR"

# --- Flatten if nested ---
INNER_DIR=$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -type d -name 'zero-connect-server-setup-*' | head -n 1)
if [[ -n "$INNER_DIR" ]]; then
  echo "[INFO] Nested folder detected. Flattening..."
  cp -r "$INNER_DIR"/* "$INSTALL_DIR/"
  rm -rf "$INNER_DIR"
fi

# --- Token input ---
if [[ -z "$ZNC_TOKEN" ]]; then
  while true; do
    echo ""
    read -s -p "Enter your Zero Networks Connect Server token (input hidden): " TOKEN
    echo ""
    TOKEN=$(echo "$TOKEN" | tr -d '[:space:]')
    [[ -z "$TOKEN" ]] && echo "Blank token. Try again." && continue
    [[ ${#TOKEN} -lt 400 ]] && echo "Token looks short. Try again." && continue
    break
  done
else
  TOKEN=$(echo "$ZNC_TOKEN" | tr -d '[:space:]')
  echo "Using token from env var ZNC_TOKEN"
fi

# --- Move to install folder ---
cd "$INSTALL_DIR" || { echo "[ERROR] Failed to enter install folder"; exit 1; }

# --- Confirm presence of needed files ---
[[ -f "zero-connect-setup" ]] || { echo "[ERROR] zero-connect-setup missing"; exit 1; }
[[ -d "dependencies" ]] || echo "[WARNING] 'dependencies/' folder missing — may cause setup failure."

chmod +x zero-connect-setup

# --- Save token to file (optional if needed by app) ---
echo "$TOKEN" > token
chmod 600 token

# --- Launch installer ---
echo ""
echo "=============================================================="
echo "Launching Connect Server installer..."
echo "Path: $(pwd)"
echo "Token: ${TOKEN:0:20}...[redacted]"
echo "=============================================================="
echo ""

sudo ./zero-connect-setup -token "$TOKEN"

# --- Clean up token ---
rm -f token
