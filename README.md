# share-my-claude

Share your Claude Code session with a browser.

## Install

```
curl -fsSL https://raw.githubusercontent.com/cs01/share-my-claude/main/install.sh | sh
```

## Usage

Start a termpair server, then share:

```
termpair serve --port 8000 &
share-my-claude
```

```
Connection is ready. Sharing terminal at:

  http://localhost:8000/s/a3f9xK7m#xK7mN2pQ9vR1tY4w8bF3cA

 ╭────────────────────────────────────────────────────────────╮
 │                                                            │
 │  ✦ Claude Code                                             │
 │                                                            │
 │  > _                                                       │
 │                                                            │
 ╰────────────────────────────────────────────────────────────╯
```

Open the link in any browser. `share-my-claude` passes all arguments through to `termpair share`, so you can use any termpair flags:

```
share-my-claude --read-only
share-my-claude --host https://my-server.com --port 443
```

### Public server

Don't want to run your own server? Use the free public one:

```
share-my-claude --host https://chadsmith.dev/termpair --port 0
```

The server is a blind relay — all data is end-to-end encrypted and the server never sees your data.

## Who is this for?

**Use Claude from your phone or tablet.** Start a session on your machine, open the link on your phone, and use Claude from anywhere.

**Let others watch your session.** Share the link so others can see what Claude is doing in real-time. Use `--read-only` so they can't type.

**Let others control your session.** Share the link and let someone else interact with Claude on your machine. This is the default.

## Security

All data is end-to-end encrypted (AES-128-GCM). The server is a blind relay and never sees your data. The encryption key is in the URL fragment, which is never sent to the server.

## Want to share other terminal apps?

share-my-claude is built on [termpair](https://github.com/cs01/termpair), which can share any terminal app (vim, htop, your shell, etc).

---

> This project is not affiliated with or endorsed by Anthropic.
