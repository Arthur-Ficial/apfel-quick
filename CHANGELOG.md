# Changelog

## v1.0.8 — 2026-04-28

Fix: response text was unreadable in dark mode (issues #20, #23).

`MarkdownRenderer` was emitting attributed-string runs without `.foregroundColor`, so `NSTextView` fell back to a static text colour and rendered the response as black-on-dark. The fix sets `.foregroundColor: NSColor.labelColor` on every run — text, code blocks, headings, inline code, and the inter-paragraph newline runs. `labelColor` is a dynamic system colour that resolves per appearance, so the response now adapts in Light, Dark, and Auto.

- 32 markdown-renderer tests, including a new `testEveryGlyphCarriesLabelColor` that walks every character of a multi-paragraph render and asserts each carries `labelColor` (catches missed paths that single-range tests skip).
- No behaviour changes outside the renderer. Settings → Appearance → System / Light / Dark picker is unchanged.

## v1.0.7 — 2026-04-23

Removed the voice-input feature.

v1.0.5 and v1.0.6 shipped a microphone button backed by the `ohr` CLI. On installed, signed, notarized builds it never actually transcribed live microphone input — not once. Three successive patches (in-process `AVCaptureDevice.requestAccess`, audio-input entitlement, single-line entitlement XML for the AMFI kernel parser) each fixed a visible layer without fixing the end-to-end path. Rather than keep patching a subprocess architecture that fights macOS TCC + Hardened Runtime at every turn, the feature is removed in full.

- Mic button, Voice settings tab, `ohr` subprocess wrapper, microphone permission shim, voice fixture + tests — all deleted.
- `NSMicrophoneUsageDescription` removed from Info.plist.
- `com.apple.security.device.audio-input` removed from entitlements.
- Bundled `ohr` helper removed from the build script; releases no longer carry it.
- Full post-mortem kept at `docs/learnings/voice-input-ohr.md` so the next attempt at voice input doesn't repeat these mistakes. Recommendation: use Apple's in-process `Speech` framework, not a spawned CLI.

258 tests green.

## v1.0.0 — 2026-04-11

First public release.

- Global hotkey overlay (default: Ctrl+Space)
- Streaming AI replies via apfel, token by token
- Auto-copy result to clipboard (configurable)
- Local math calculator — expressions like `54,34*6-(435353)` compute instantly, no AI round-trip
- European decimal comma support
- Menu bar icon (optional)
- Launch at login (default on)
- In-app update checks via GitHub Releases
- First-run welcome overlay
- 168 tests, TDD-first
- MIT license
