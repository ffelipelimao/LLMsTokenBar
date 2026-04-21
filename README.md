# LLMsTokenBar

<img width="333" height="424" alt="Captura de Tela 2026-03-25 às 16 23 50" src="https://github.com/user-attachments/assets/d89c43c6-803d-405e-b1f7-6691b48af235" />

A native macOS menu bar app that tracks your LLM token usage and estimated cost in real-time.

![Menu Bar Preview](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- Real-time usage limits from Anthropic API (Session 5h, Weekly All, Weekly Sonnet)
- Rolling window progress bars matching Claude's actual usage system
- Shows I/O tokens, cost, and usage percentage in the menu bar
- Today and Yesterday usage breakdown
- **Hallucination-risk indicator** per active session (context-fill %, color-coded, with menu bar tint and notifications on threshold crossings)
- Auto-refresh via directory watcher + 60s timer
- Reads OAuth token from macOS Keychain (requires Claude Code login)
- Extensible provider architecture for future LLM providers

## Supported Providers

- **Claude Code** — reads session data from `~/.claude/projects/` JSONL files and usage limits from Anthropic's OAuth API

## Requirements

- macOS 14.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)
- Claude Code logged in (for OAuth token access)

## Build

```bash
brew install xcodegen
cd LLMsTokenBar
xcodegen generate
open LLMsTokenBar.xcodeproj
```

Build and run with `Cmd+R`. The app appears in the menu bar (no Dock icon).

### Run from command line

```bash
xcodebuild -project LLMsTokenBar.xcodeproj -scheme LLMsTokenBar -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/LLMsTokenBar-*/Build/Products/Debug/LLMsTokenBar.app
```

## Understanding Cost Estimates

The estimated cost includes all token types charged by Anthropic:

| Token Type | Rate (Opus) | Description |
|---|---|---|
| Input | $15/MTok | Your messages sent to Claude |
| Output | $75/MTok | Claude's responses |
| Cache Read | $1.50/MTok | Re-reading cached conversation context |
| Cache Creation | $18.75/MTok | Creating new cache entries |

**Why does cost seem high?** Each message in a long session re-reads the full growing context from cache. So the longer the session, the more cache tokens accumulate — a 100-message session reads the entire conversation history 100 times from cache. Cache reads are cheap ($1.50/MTok vs $15/MTok for regular input), but they add up over long sessions and are the largest contributor to total cost.

## Understanding Hallucination Risk

As an LLM's context window fills up, accuracy degrades — a phenomenon documented in research like *"Lost in the Middle"* (Liu et al. 2024) and Chroma's *"Context Rot"* (2025). LLMsTokenBar surfaces this as a per-session indicator.

### How it's computed

For each active session (JSONL modified today), the app reads the **last assistant message's** `usage` block and computes:

```
contextTokens = input_tokens + cache_read_input_tokens + cache_creation_input_tokens
fillPercent   = contextTokens / contextWindowSize × 100
```

The sum equals the total input context at that turn. The window size is inferred from the model name (`200K` by default, `1M` for extended-context variants). When observed context exceeds 200K, the app auto-detects a 1M deployment.

### Thresholds

| Level      | Range    | Meaning |
|------------|----------|---------|
| Low        | <50%     | Full accuracy territory |
| Moderate   | 50-75%   | Recall of middle-context details starts to weaken |
| High       | 75-90%   | Measurable accuracy loss; hallucinations more likely |
| Critical   | ≥90%     | Strong degradation — start a fresh session |

### Where it shows up

- **Popover** — a per-session list under "Hallucination Risk", one row per session with project name, fill %, color-coded mini bar, and a caption showing `used / window · model` (e.g. `128K / 200K · opus-4-7`).
- **Menu bar** — the usage label tints orange when any session crosses 75% and red at ≥90%.
- **macOS notifications** — fire once when a session *crosses upward* into the `High` or `Critical` band, naming the specific session. The notification does not repeat while the session stays in that band.

### Limitations

- The stock model string (`claude-opus-4-7`) doesn't encode the context tier. Sessions under 200K on the 1M tier will over-report risk (conservative, not wrong).
- Cache-read tokens sum across all cache prefixes, which can slightly overstate the model's effective working set (≤1-2% drift in practice).
- Auto-compaction in Claude Code resets the bar to a low value; this reflects the model's state correctly but hides the fact that detail was discarded.

## Adding a New Provider

1. Create a new class implementing the `UsageProvider` protocol
2. Add pricing to `LLMProviderType`
3. Register it in `UsageViewModel.init()`

## License

MIT
