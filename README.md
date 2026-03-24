# Share My Claude

Share your Claude Code session over the web. Public or private, one command.

<p align="center">
<img src="sharemyclaude_terminal.png" width="500" alt="sharemyclaude terminal"/>
</p>
<p align="center">
<img src="sharemyclaude_browser.png" width="600" alt="sharemyclaude browser view"/>
</p>

**Access Claude from your phone** -- start a session on your machine, open the link on any device, and control Claude from anywhere.

**Share publicly** -- broadcast your session on the [sharemyclau.de](https://sharemyclau.de) landing page for anyone to watch.

**Share privately** -- end-to-end encrypted by default. Only people with the link can view your session.

**Watch others** -- browse public sessions on [sharemyclau.de](https://sharemyclau.de) and watch Claude work in real-time.

## Install

```
curl -fsSL https://raw.githubusercontent.com/cs01/sharemyclaude/main/install.sh | sh
```

This installs `termpair` (the server/client) and `sharemyclaude` (a wrapper that connects to sharemyclau.de and launches `claude`).

## Quick Start

```
sharemyclaude
```

That's it. After pressing Enter, Claude Code launches normally -- you use it exactly as you always do. The only difference is that your terminal session is mirrored live to a shareable link that anyone with the URL can watch (or type in) from their browser.

**Public session** (listed on the landing page, anyone can find it):

```
sharemyclaude --public
```

**Private session** (end-to-end encrypted, only people with the link can view):

```
sharemyclaude
```

## Options

```
sharemyclaude                          # private encrypted session (default)
sharemyclaude --public                 # listed on sharemyclau.de, no encryption
sharemyclaude --read-only              # viewers can watch but can't type
sharemyclaude -- --model sonnet        # pass flags to claude after --
sharemyclaude -- --dangerously-skip-permissions  # skip claude's permission prompts
```

## Security

Private sessions are end-to-end encrypted (AES-128-GCM). The server is a blind relay -- it routes messages but never decrypts them. The encryption key lives in the URL fragment, which is never sent to the server.

Public sessions (`--public`) are **not encrypted** -- they are listed on the landing page and viewable by anyone. Use private mode (the default) when sharing sensitive work.

## Built on termpair

sharemyclaude is a wrapper around [termpair](https://github.com/cs01/termpair), which provides end-to-end encrypted terminal sharing for any terminal app -- vim, htop, your shell, or anything else. If you want to self-host or share non-Claude sessions, check out termpair directly.

---

> This project is not affiliated with or endorsed by Anthropic.
