# sharemyclaude

Share your Claude Code session with a browser.

## Who is this for?

**Use Claude from your phone or tablet.** Start a session on your machine, open the link on your phone, and use Claude from anywhere.

**Let others watch your session.** Share the link so others can see what Claude is doing in real-time. Use `--read-only` so they can't type.

**Let others control your session.** Share the link and let someone else interact with Claude on your machine. This is the default.

## Install

```
curl -fsSL https://raw.githubusercontent.com/cs01/sharemyclaude/main/install.sh | sh
```

This installs `termpair` (the server/client) and `sharemyclaude` (a wrapper that connects to sharemyclau.de and launches `claude`).

## Quick Start

```
sharemyclaude
```

That's it. It connects to the public server at sharemyclau.de, launches Claude Code, and gives you a link to share.

**Public session** (listed on the landing page, anyone can find it):

```
sharemyclaude --public
```

**Private session** (end-to-end encrypted, only people with the link can view):

```
sharemyclaude
```

## Options

All arguments are passed through to `termpair share`:

```
sharemyclaude --read-only       # viewers can only watch, can't type
sharemyclaude --public          # listed on sharemyclau.de landing page
sharemyclaude --host http://localhost --port 8000  # use your own server
sharemyclaude --skill           # print instructions for AI agents
```

## Security

Private sessions are end-to-end encrypted (AES-128-GCM). The server is a blind relay — it routes messages but never decrypts them. The encryption key lives in the URL fragment, which is never sent to the server.

Public sessions (`--public`) are **not encrypted** — they are listed on the landing page and viewable by anyone. Use private mode (the default) when sharing sensitive work.

## Want to share other terminal apps?

sharemyclaude is built on [termpair](https://github.com/cs01/termpair), which can share any terminal app (vim, htop, your shell, etc).

---

> This project is not affiliated with or endorsed by Anthropic.
