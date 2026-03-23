#!/bin/sh
set -eu

TERMPAIR_REPO="cs01/termpair"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

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

add_to_path() {
  case ":$PATH:" in
    *":$INSTALL_DIR:"*) return ;;
  esac

  rc=""
  if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "zsh" ]; then
    rc="$HOME/.zshrc"
  elif [ -n "${BASH_VERSION:-}" ] || [ "$(basename "${SHELL:-}")" = "bash" ]; then
    rc="$HOME/.bashrc"
  elif [ -f "$HOME/.profile" ]; then
    rc="$HOME/.profile"
  fi

  if [ -n "$rc" ] && [ -f "$rc" ]; then
    if ! grep -q "$INSTALL_DIR" "$rc" 2>/dev/null; then
      echo "" >> "$rc"
      echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$rc"
    fi
  fi
}

main() {
  platform="$(detect_platform)"
  version="${VERSION:-$(get_latest_version)}"

  if [ -z "$version" ]; then
    echo "Could not determine latest version" >&2; exit 1
  fi

  echo "Installing sharemyclaude (termpair ${version}) for ${platform}..."

  mkdir -p "$INSTALL_DIR"

  url="https://github.com/${TERMPAIR_REPO}/releases/download/${version}/termpair-${platform}.tar.gz"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  download "$url" "$tmp/termpair.tar.gz"
  tar xzf "$tmp/termpair.tar.gz" -C "$tmp"

  mv "$tmp/termpair" "$INSTALL_DIR/termpair"
  chmod +x "$INSTALL_DIR/termpair"

  ln -sf "$INSTALL_DIR/termpair" "$INSTALL_DIR/sharemyclaude"

  add_to_path

  echo ""
  echo "Installed to $INSTALL_DIR"
  echo ""
  case ":$PATH:" in
    *":$INSTALL_DIR:"*)
      echo "Run it:"
      echo "  sharemyclaude"
      ;;
    *)
      echo "Run this to add it to your PATH (or restart your shell):"
      echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
      echo ""
      echo "Then:"
      echo "  sharemyclaude"
      ;;
  esac
}

main
