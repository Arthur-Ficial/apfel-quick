# apfel-quick

**Instant AI overlay for macOS. Press a key. Ask anything. Done.**

A Spotlight-style overlay powered entirely by on-device AI. Hit `Ctrl+Space`, type a prompt, press `Return` — the answer streams in and lands on your clipboard. No cloud, no API keys, no waiting. Math expressions are computed locally in microseconds and never touch the model.

**[apfel-quick.franzai.com](https://apfel-quick.franzai.com)**

[![Latest Release](https://img.shields.io/github/v/release/Arthur-Ficial/apfel-quick?label=latest&color=0066cc)](https://github.com/Arthur-Ficial/apfel-quick/releases/latest)
[![MIT License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B%20Tahoe-blue.svg)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2B-black.svg)](https://www.apple.com/mac/)
[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)

---

## Screenshots

<table>
<tr>
<td align="center">
<img src="docs/screen-overlay.png" width="520" alt="apfel-quick overlay"><br>
<strong>Overlay</strong> — global hotkey, streaming reply, auto-copied to clipboard
</td>
</tr>
</table>

---

## What it does

apfel-quick puts a private AI assistant one keystroke away. It is a small floating panel that lives above every window — no Dock icon, no menu bar clutter (unless you want it), no browser tab to find.

- **Press the hotkey** — `Option+Space` by default, fully configurable
- **Type your prompt** — anything you would ask a chatbot
- **Press Return** — the answer streams in token by token from your local Foundation Models
- **Press Escape** — overlay disappears, the result is already on your clipboard, paste it anywhere

For pure math like `54,34*6-(435353)`, apfel-quick recognises the expression and evaluates it locally without any AI round-trip. Instant. Deterministic. Zero context cost.

It runs offline. Nothing leaves your Mac. There is no account, no telemetry, no API key.

---

## Features

| Feature | Details |
|---|---|
| **Global hotkey** | Default `Option+Space`, rebindable in settings |
| **Streaming replies** | Token-by-token SSE from the local apfel server |
| **Auto-copy** | Result lands on the clipboard the moment streaming finishes (togglable) |
| **Local math shortcut** | `+ - * / ^ %`, parentheses, `sqrt sin cos tan log ln abs floor ceil round`, constants `pi e`, European decimal comma — all evaluated locally |
| **Menu bar icon** | Optional status item for quick access |
| **Launch at login** | On by default via `ServiceManagement` |
| **In-app updates** | Checks GitHub Releases on launch, one-click upgrade via Homebrew or download |
| **First-run welcome** | One-shot onboarding overlay on first launch |
| **Fully on-device** | No network calls for AI, no API keys, no telemetry |
| **168 tests** | TDD-first, swift-testing, every service has a protocol + mock |

---

## Requirements

| Requirement | How to check |
|---|---|
| **macOS 26 (Tahoe) or later** | Apple menu → About This Mac |
| **Apple Silicon (M1 or later)** | Apple menu → About This Mac — must say M1, M2, M3, or M4 |
| **On-device AI enabled** | System Settings → enable on-device AI / Foundation Models |

> **`apfel` (AI engine):** Packaged builds — ZIP download and Homebrew cask — bundle it inside the app automatically. Nothing extra to install. Source builds only: `brew install Arthur-Ficial/tap/apfel`.

---

## Install

### Option 1 — Homebrew (recommended)

```bash
brew install Arthur-Ficial/tap/apfel-quick

# Update later
brew upgrade apfel-quick
```

> Don't have Homebrew? Get it at [brew.sh](https://brew.sh).

### Option 2 — Direct download (zip)

1. Download the latest ZIP from the [releases page](https://github.com/Arthur-Ficial/apfel-quick/releases/latest)
2. Unzip it
3. Drag `apfel-quick.app` to `/Applications`
4. Launch it once — grant Accessibility permission so the global hotkey can work

### Option 3 — Build from source

```bash
git clone https://github.com/Arthur-Ficial/apfel-quick.git
cd apfel-quick
make install
```

Requires Xcode command-line tools and `apfel` on your `PATH`.

---

## Usage

The whole app is one workflow:

1. Press **`Option+Space`** — the overlay appears centred on screen
2. **Type** your prompt
3. Press **`Return`** — the reply streams in below the input
4. Press **`Escape`** — overlay closes, the answer is already on your clipboard
5. **`Cmd+V`** anywhere to paste

### Math shortcut

If your input is a pure math expression, apfel-quick skips the AI entirely and computes the result locally with a recursive-descent parser:

```
54,34*6-(435353)        →   -435026,96
sqrt(2)^2               →   2
(1+2)*3 - 4/2           →   7
sin(pi/2)               →   1
```

European decimal commas (`3,14`) are supported alongside dots. Functions: `sqrt sin cos tan log ln abs floor ceil round`. Constants: `pi e`. Operators: `+ - * / ^ %`. The result is formatted, copied to your clipboard, and shown — all in microseconds.

### Cancel a stream

While a reply is streaming you can press the cancel control to abort. The overlay clears and you are back to typing.

---

## Configuration

Open the settings dialog from the overlay to adjust:

| Setting | Default | What it does |
|---|---|---|
| **Hotkey** | `Option+Space` | The global key chord that summons the overlay |
| **Auto-copy result** | On | Copies the streamed reply (or math result) to the clipboard automatically |
| **Launch at login** | On | Starts apfel-quick when you log in via `ServiceManagement` |
| **Show menu bar icon** | On | Optional status item in the menu bar |
| **Check for updates on launch** | On | Checks GitHub Releases for a newer version |

Settings are persisted to `UserDefaults` under the `QuickSettings` key.

---

## How it works

apfel-quick is a `LSUIElement` SwiftUI app — no Dock icon, no main window. The hotkey is registered with the system. When you press it:

1. An `NSPanel` overlay slides in above all other windows
2. You type a prompt; pressing `Return` calls `QuickViewModel.submit()`
3. The view model first asks `MathExpressionDetector` whether the input is a pure math expression
4. **If yes:** `MathCalculator` evaluates it locally with a recursive-descent parser (operators, parentheses, functions, constants, European commas) and the result is formatted and copied to the clipboard. The AI is never invoked.
5. **If no:** the prompt is sent to the local `apfel --serve` HTTP server via `/v1/chat/completions`. Tokens stream back over SSE, are appended to `output` as they arrive, and the final string is copied to the clipboard when the stream completes.
6. Press `Escape` and the overlay hides until next time.

The server lifecycle is managed by `ServerManager` — it spawns `apfel --serve` on the first available port in the range and reuses an existing instance if one is already running. Launch-at-login is wired through Apple's `ServiceManagement` framework. Updates are checked against the GitHub Releases API and installed via `brew upgrade` if you installed via Homebrew, otherwise the latest release page opens in your browser.

---

## Architecture

```
App/                — entry point, NSPanel, hotkey registration, AppDelegate
Models/             — QuickSettings, StreamDelta, UpdateState
Protocols/          — QuickService and other service contracts
Services/
  ├─ ApfelQuickService           — SSE streaming via /v1/chat/completions
  ├─ ServerManager               — spawns apfel --serve, port discovery
  ├─ SSEParser                   — server-sent events line parser
  ├─ MathExpressionDetector      — tokeniser deciding "is this pure math?"
  ├─ MathCalculator              — recursive-descent expression evaluator
  └─ SystemLaunchAtLoginController — ServiceManagement wrapper
ViewModels/
  └─ QuickViewModel              — overlay state, submit, cancel, copy, updates
Views/
  ├─ OverlayView                 — input + streaming output
  ├─ SettingsView                — preferences dialog
  └─ WelcomeOverlayView          — first-run onboarding
```

`@Observable` view models, Swift 6.3 strict concurrency, no external dependencies beyond `swift-testing`. SwiftUI + AppKit + ServiceManagement only.

---

## Building from source

```bash
swift test                  # run the full 168-test suite
swift build -c release      # release binary
make install                # build the .app and copy to /Applications
./scripts/release.sh        # full release: test, build, sign, notarise, tag, publish
```

Tests cover the SSE parser, the chat service, the math calculator and detector, the view model, settings persistence, server manager, system launch-at-login, and update version comparison. All 168 must pass before a release goes out.

---

## Open source / Contributing

Issues and PRs welcome at **[github.com/Arthur-Ficial/apfel-quick/issues](https://github.com/Arthur-Ficial/apfel-quick/issues)**.

Bug reports should include macOS version, hardware, and a minimal repro. Feature requests are evaluated against the project's purpose: a fast, private, local overlay. If it would slow startup, add a network dependency, or grow the surface area, it probably will not land.

---

## License

MIT — see [LICENSE](LICENSE).

---

## See also

- **[apfel-chat](https://github.com/Arthur-Ficial/apfel-chat)** — multi-conversation on-device AI chat for macOS, the consumer chat client sibling to apfel-quick
- **[apfel](https://github.com/Arthur-Ficial/apfel)** — CLI + OpenAI-compatible server for the on-device LLM, the engine under both apps
