# Pixel Terminal

A native macOS terminal built with Swift + SwiftTerm. Dark "Midnight Pine" theme, smart suggestions, Claude Code integration, and a network command palette for IT/security workflows — no Electron, no subscriptions.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **Multiple sessions** — left sidebar with running-process indicators and per-session git status (branch, ahead/behind, dirty)
- **Smart suggestions** — frequency × recency × directory scoring, built-in subcommand knowledge for 15+ CLIs, typo correction via Levenshtein distance. No AI API required.
- **Claude API suggestions** — optional: add your Anthropic API key in Settings to get AI-powered completions alongside local ones
- **Claude Code quick launch** — `⌘⇧C` opens a new session in the current directory and runs `claude` automatically, with a sidebar badge
- **Network command palette** (`⌘⇧N`) — searchable library of 50+ network/security commands across 8 categories (DNS, SSH, Traffic Capture, HTTP, nmap, etc.) with one-click insert
- **Plain-language network suggestions** — type `open ports`, `flush dns`, `my public ip` and get the right command as a suggestion
- **Custom shell prompt** — `pixel-terminal:user ~/dir >` with true-color ANSI, works for zsh and bash
- **Branded greeting** — replaces the default zsh/bash startup noise with a themed welcome screen
- **Git status** in sidebar and status bar — branch, ahead ↑ / behind ↓, dirty dot
- **macOS Keychain** — GitHub PAT, Vercel token, and Anthropic API key stored encrypted, never in plaintext
- **Status bar** — git info, CWD, shell type, terminal dimensions, settings gear
- **Portable** — single `.app` bundle, no installer required, DMG for easy distribution

---

## Requirements

- macOS 13 Ventura or later
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+ (bundled with Xcode CLT)

---

## Build from source

```bash
git clone https://github.com/ryanjames1729/pixel-terminal.git
cd pixel-terminal

# Generate app icon (one time)
swift makeIcon.swift

# Build and package
bash build.sh

# Run
open "dist/Pixel Terminal.app"
```

The built `.app` is self-contained — copy it to `/Applications` or distribute as a DMG.

### Build a DMG for distribution

```bash
bash build.sh   # builds dist/Pixel Terminal.app
hdiutil create -volname "Pixel Terminal" \
  -srcfolder dist/ \
  -ov -format UDZO \
  dist/PixelTerminal.dmg
```

---

## Optional: AI-powered suggestions

1. Get an API key from [console.anthropic.com](https://console.anthropic.com)
2. Open Pixel Terminal → **Settings → Integrations**
3. Paste your `sk-ant-…` key and click **Save**

Suggestions from Claude (marked ✦) appear alongside local ones. Falls back to local-only if the API is unreachable.

---

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `⌘T` | New session |
| `⌘W` | Close session |
| `⌘⇧C` | Launch Claude Code in current directory |
| `⌘⇧N` | Open Network Command Palette |
| `⌘K` | Clear terminal |
| `⌘,` | Settings |
| `Tab` | Accept top suggestion |
| `Esc` | Dismiss suggestions |
| `↑ ↓` | Navigate suggestions |

---

## Architecture

```
Sources/PixelTerminal/
  PixelTerminalApp.swift      — @main entry, menu commands, notification names
  ContentView.swift           — root layout, suggestion scheduling, palette overlay
  Models/
    TabManager.swift          — @MainActor session state, git polling
    AppSettings.swift         — UserDefaults-backed settings
  Views/
    SidebarView.swift         — session list, git badge, Claude badge, running dot
    TerminalAreaView.swift    — NSViewRepresentable bridge, shell rc injection, greeting
    StatusBarView.swift       — bottom bar (git, CWD, shell, size, settings)
    SuggestionsView.swift     — autocomplete overlay
    NetworkPaletteView.swift  — ⌘⇧N searchable command palette
    SettingsView.swift        — appearance / integrations / shell settings
  Services/
    SuggestionsEngine.swift   — local scoring + Claude API augmentation
    GitStatusService.swift    — async git subprocess runner
    CredentialStore.swift     — macOS Keychain wrapper
  Data/
    NetworkCommands.swift     — 50+ network commands + plain-language phrase map
```

Dependencies: [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) (terminal emulation)

---

## License

MIT
