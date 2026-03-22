# share-my-claude

Share your Claude Code terminal session with anyone via a link.

## Install

```
curl -fsSL https://raw.githubusercontent.com/cs01/share-my-claude/main/install.sh | sh
```

## Usage

```
$ share-my-claude
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

Send the link to anyone. They can watch (or control) your Claude session from their browser. Fully end-to-end encrypted — the server never sees your data.

### Options

```
share-my-claude --read-only    # viewers can only watch
share-my-claude --port 9000    # different port
```

## Want to share other terminal apps?

share-my-claude is built on [termpair](https://github.com/cs01/termpair), which can share any terminal app (vim, htop, your shell, etc).

---

> This project is not affiliated with or endorsed by Anthropic.
