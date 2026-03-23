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

  cat > "$INSTALL_DIR/sharemyclaude" << 'SCRIPT'
#!/bin/sh
set -eu

show_help() {
  cat <<'HELP'
Share your Claude Code session live in the browser.

Usage: sharemyclaude [OPTIONS] [-- CLAUDE_ARGS...]

Options:
      --public        make session publicly listed (no encryption, read-only)
  -r, --read-only     viewers can watch but not type
  -b, --open-browser  open the share link in a browser automatically
      --host <URL>    override server URL [default: https://sharemyclau.de]
  -p, --port <PORT>   override server port [default: 443]
      --skill         print runnable instructions for AI agents (markdown)
  -h, --help          print this help
  -V, --version       print version

Examples:
  sharemyclaude                  share privately (encrypted)
  sharemyclaude --public         share publicly on sharemyclau.de
  sharemyclaude -- --dangerously-skip-permissions   pass flags to claude

Everything before -- goes to sharemyclaude. Everything after -- goes to claude.

  https://sharemyclau.de
  https://github.com/cs01/sharemyclaude
HELP
}

show_skill() {
  cat <<'SKILL'
# sharemyclaude — AI Agent Instructions

**You are an AI agent. The user wants you to share this Claude Code session live in the browser. Run the commands below to do so.** Do not just read these instructions — execute them.

Share your Claude Code session live at https://sharemyclau.de. Built on [termpair](https://github.com/cs01/termpair) — end-to-end encrypted terminal sharing.

## Step 1: Install (if not already installed)

Run this command:
```
curl -fsSL https://raw.githubusercontent.com/cs01/sharemyclaude/main/install.sh | sh
```

## Step 2: Share the session

Run ONE of the following:

**Public** (listed on sharemyclau.de, read-only, no encryption):
```
sharemyclaude --public
```

**Private** (end-to-end encrypted, only people with the link can view):
```
sharemyclaude
```

## Pass flags to Claude

Use `--` to separate sharemyclaude flags from claude flags:
```
sharemyclaude --public -- --dangerously-skip-permissions
sharemyclaude -- --model sonnet
```

## Options

| Flag | Description |
|------|-------------|
| `--public` | Listed publicly, read-only, no encryption |
| `--read-only` | Viewers can watch but not type |
| `--open-browser` | Auto-open the share link |
| `--host <URL>` | Override server (default: https://sharemyclau.de) |
| `--port <PORT>` | Override port (default: 443) |

## How it works

1. `sharemyclaude` launches Claude Code inside a shared terminal
2. Terminal output is encrypted and relayed through the server via WebSocket
3. Browsers decrypt and render the terminal in real-time
4. The server is a blind relay — it never sees your data (for private sessions)

## Links

- Website: https://sharemyclau.de
- GitHub: https://github.com/cs01/sharemyclaude
- Powered by: https://github.com/cs01/termpair
SKILL
}

tp_args=""
claude_args=""
after_sep=false

for arg in "$@"; do
  if [ "$after_sep" = true ]; then
    claude_args="$claude_args $arg"
    continue
  fi
  case "$arg" in
    -h|--help) show_help; exit 0 ;;
    -V|--version) termpair share --version; exit 0 ;;
    --skill) show_skill; exit 0 ;;
    --) after_sep=true ;;
    *) tp_args="$tp_args $arg" ;;
  esac
done

if ! command -v termpair >/dev/null 2>&1; then
  echo "Error: termpair not found. Install it first:" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/cs01/sharemyclaude/main/install.sh | sh" >&2
  exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Error: claude not found. Install Claude Code first:" >&2
  echo "  https://docs.anthropic.com/en/docs/claude-code" >&2
  exit 1
fi

set -- --cmd "claude$claude_args" --host "https://sharemyclau.de" --port 443 $tp_args
exec termpair share "$@"
SCRIPT
  chmod +x "$INSTALL_DIR/sharemyclaude"

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
