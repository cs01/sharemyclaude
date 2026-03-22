# share-my-claude

Share your [Claude Code](https://claude.ai/code) session with anyone via a link. Viewers can watch or control your Claude session in real-time from their browser — fully end-to-end encrypted.

Built on [termpair](https://github.com/cs01/termpair).

## Install

```
curl -fsSL https://raw.githubusercontent.com/cs01/share-my-claude/main/install.sh | sh
```

## Usage

```
share-my-claude
```

That's it. A link will be printed and opened in your browser. Share the link with anyone.

### Options

```
share-my-claude --read-only     # viewers can only watch, not type
share-my-claude --port 9000     # use a different port
share-my-claude --cmd "claude --allowedTools bash" # pass args to claude
```

## How it works

1. Starts a local termpair server
2. Launches `claude` in a shared terminal
3. Gives you a link to share

All terminal data is end-to-end encrypted — the server is a blind relay and never sees your data. The encryption key is in the URL hash fragment (never sent to the server).

## Security

- End-to-end encrypted with AES-128-GCM
- Server never sees plaintext
- Encryption key stays in the URL fragment
- Use `--read-only` if you don't want viewers to control your session
