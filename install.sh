#!/bin/sh
set -eu

TERMPAIR_REPO="cs01/termpair"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

detect_platform() {
  os="$(uname -s)"
  arch="$(uname -m)"

  case "$os" in
    Linux)  os="unknown-linux-gnu" ;;
    Darwin) os="apple-darwin" ;;
    MINGW*|MSYS*|CYGWIN*) echo "On Windows, download from https://github.com/${TERMPAIR_REPO}/releases" >&2; exit 1 ;;
    *) echo "Unsupported OS: $os" >&2; exit 1 ;;
  esac

  case "$arch" in
    x86_64|amd64)  arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
  esac

  echo "${arch}-${os}"
}

get_latest_version() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "https://api.github.com/repos/${TERMPAIR_REPO}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"//;s/".*//'
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "https://api.github.com/repos/${TERMPAIR_REPO}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"//;s/".*//'
  else
    echo "Neither curl nor wget found" >&2; exit 1
  fi
}

download() {
  url="$1"; dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  else
    wget -qO "$dest" "$url"
  fi
}

main() {
  platform="$(detect_platform)"
  version="${VERSION:-$(get_latest_version)}"

  if [ -z "$version" ]; then
    echo "Could not determine latest version" >&2; exit 1
  fi

  echo "Installing share-my-claude (termpair ${version}) for ${platform}..."

  url="https://github.com/${TERMPAIR_REPO}/releases/download/${version}/termpair-${platform}.tar.gz"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  download "$url" "$tmp/termpair.tar.gz"
  tar xzf "$tmp/termpair.tar.gz" -C "$tmp"

  if [ -w "$INSTALL_DIR" ]; then
    mv "$tmp/termpair" "$INSTALL_DIR/termpair"
  else
    echo "Installing to ${INSTALL_DIR} (requires sudo)..."
    sudo mv "$tmp/termpair" "$INSTALL_DIR/termpair"
  fi
  chmod +x "$INSTALL_DIR/termpair"

  cat > "$tmp/share-my-claude" << 'SCRIPT'
#!/bin/sh
set -eu

HOST="${HOST:-http://localhost}"
PORT="${PORT:-8000}"
CMD="${CMD:-claude}"
READ_ONLY=""

usage() {
  echo "Usage: share-my-claude [options]"
  echo ""
  echo "Share your Claude Code session with anyone via a link."
  echo "Starts a server and shares your terminal in one command."
  echo ""
  echo "Options:"
  echo "  --host URL     server host (default: http://localhost)"
  echo "  --port PORT    server port (default: 8000)"
  echo "  --cmd CMD      command to run (default: claude)"
  echo "  --read-only    prevent viewers from typing"
  echo "  -h, --help     show this help"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --cmd) CMD="$2"; shift 2 ;;
    --read-only) READ_ONLY="--read-only"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if ! command -v termpair >/dev/null 2>&1; then
  echo "error: termpair not found. Install it first:" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/cs01/share-my-claude/main/install.sh | sh" >&2
  exit 1
fi

cleanup() {
  if [ -n "${SERVER_PID:-}" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

termpair serve --port "$PORT" &
SERVER_PID=$!
sleep 1

termpair share --cmd "$CMD" --host "$HOST" --port "$PORT" --open-browser $READ_ONLY
SCRIPT

  if [ -w "$INSTALL_DIR" ]; then
    mv "$tmp/share-my-claude" "$INSTALL_DIR/share-my-claude"
  else
    sudo mv "$tmp/share-my-claude" "$INSTALL_DIR/share-my-claude"
  fi
  chmod +x "$INSTALL_DIR/share-my-claude"

  echo ""
  echo "Installed share-my-claude to ${INSTALL_DIR}/share-my-claude"
  echo ""
  echo "Run it:"
  echo "  share-my-claude"
}

main
