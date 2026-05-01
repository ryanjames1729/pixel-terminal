# pixel-terminal

Install [Pixel Terminal](https://github.com/ryanjames1729/pixel-terminal) with a single command.

```bash
npx pixel-terminal
```

That's it. The installer will:
1. Download the latest release DMG from GitHub
2. Mount it and copy **Pixel Terminal.app** to your Applications folder
3. Remove the quarantine flag so Gatekeeper doesn't block it
4. Launch the app

**Requirements:** macOS 13 Ventura or later, Node.js 16+

---

## What is Pixel Terminal?

A native macOS terminal built with Swift. No Electron. No subscriptions.

- **Smart suggestions** — frequency × recency × directory scoring, built-in CLI knowledge, typo correction. No AI API required.
- **Claude Code quick launch** — `⌘⇧C` opens a session and runs `claude` automatically
- **Claude API suggestions** — optional, add your Anthropic key in Settings
- **Network command palette** (`⌘⇧N`) — 50+ network/security commands, searchable, one-click insert
- **Plain-language suggestions** — type `open ports`, `flush dns`, `my public ip` and get the right command
- **Custom prompt** — `pixel-terminal:user ~/dir >` with true-color ANSI
- **Git status** in sidebar — branch, ahead/behind, dirty indicator
- **macOS Keychain** — credentials stored encrypted, never in plaintext

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘T` | New session |
| `⌘W` | Close session |
| `⌘⇧C` | Launch Claude Code |
| `⌘⇧N` | Network command palette |
| `⌘K` | Clear terminal |
| `⌘,` | Settings |
| `Tab` | Accept suggestion |
| `Esc` | Dismiss suggestions |

## Source

[github.com/ryanjames1729/pixel-terminal](https://github.com/ryanjames1729/pixel-terminal)
