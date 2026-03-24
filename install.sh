#!/bin/sh
set -eu

TERMPAIR_REPO="cs01/termpair"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

if [ -t 1 ]; then
  bold="\033[1m" dim="\033[2m" green="\033[32m" cyan="\033[36m"
  yellow="\033[33m" red="\033[31m" reset="\033[0m"
else
  bold="" dim="" green="" cyan="" yellow="" red="" reset=""
fi

info()  { printf "  ${cyan}>${reset} %s\n" "$1"; }
ok()    { printf "  ${green}>${reset} %s\n" "$1"; }
warn()  { printf "  ${yellow}!${reset} %s\n" "$1" >&2; }
err()   { printf "  ${red}x${reset} %s\n" "$1" >&2; exit 1; }

detect_platform() {
  os="$(uname -s)"; arch="$(uname -m)"
  case "$os" in
    Linux)  os="unknown-linux-gnu" ;;
    Darwin) os="apple-darwin" ;;
    MINGW*|MSYS*|CYGWIN*) err "On Windows, download from https://github.com/${TERMPAIR_REPO}/releases" ;;
    *) err "Unsupported OS: $os" ;;
  esac
  case "$arch" in
    x86_64|amd64)  arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *) err "Unsupported architecture: $arch" ;;
  esac
  echo "${arch}-${os}"
}

get_latest_version() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "https://api.github.com/repos/${TERMPAIR_REPO}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"//;s/".*//'
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "https://api.github.com/repos/${TERMPAIR_REPO}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"//;s/".*//'
  else
    err "Neither curl nor wget found"
  fi
}

download() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  else wget -qO "$2" "$1"; fi
}

main() {
  printf "\n"
  printf "  ${bold}Share My Claude${reset}\n"
  printf "  ${dim}Share your Claude Code sessions live in the browser${reset}\n"
  printf "\n"

  platform="$(detect_platform)"
  version="${VERSION:-$(get_latest_version)}"
  [ -z "$version" ] && err "Could not determine latest version"

  info "Downloading sharemyclaude ${version} (${platform})..."

  url="https://github.com/${TERMPAIR_REPO}/releases/download/${version}/termpair-${platform}.tar.gz"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  download "$url" "$tmp/termpair.tar.gz"
  tar xzf "$tmp/termpair.tar.gz" -C "$tmp"

  mkdir -p "$INSTALL_DIR"
  mv "$tmp/termpair" "$INSTALL_DIR/termpair"
  chmod +x "$INSTALL_DIR/termpair"
  ln -sf "$INSTALL_DIR/termpair" "$INSTALL_DIR/sharemyclaude"

  ok "Installed to ${INSTALL_DIR}"

  case ":$PATH:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
      printf "\n"
      warn "${INSTALL_DIR} is not in your PATH. Add it:"
      printf "    ${bold}export PATH=\"${INSTALL_DIR}:\$PATH\"${reset}\n"
      printf "    ${dim}Add to ~/.bashrc or ~/.zshrc to make permanent${reset}\n"
      ;;
  esac

  printf "\n"
  printf "  ${bold}Quick start${reset}\n"
  printf "\n"
  printf "    ${green}sharemyclaude${reset}                   Share a private Claude Code session\n"
  printf "    ${green}sharemyclaude --public${reset}          Public session (listed on sharemyclau.de)\n"
  printf "    ${green}sharemyclaude -- --model sonnet${reset} Pass flags to Claude after --\n"
  printf "\n"
  printf "  ${bold}How it works${reset}\n"
  printf "\n"
  printf "    1. sharemyclaude launches Claude Code inside a shared terminal\n"
  printf "    2. Terminal output is encrypted and relayed via WebSocket\n"
  printf "    3. Viewers open the link in a browser to watch in real-time\n"
  printf "    4. The server never sees your data ${dim}(end-to-end encrypted)${reset}\n"
  printf "\n"
  printf "  ${dim}https://sharemyclau.de${reset}\n"
  printf "\n"
}

main
