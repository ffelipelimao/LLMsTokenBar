# LLMsTokenBar

<img width="346" height="406" alt="Captura de Tela 2026-03-25 às 14 22 35" src="https://github.com/user-attachments/assets/828ecc34-02d3-4188-a81e-5bc222fe0693" />

A native macOS menu bar app that tracks your LLM token usage and estimated cost in real-time.

![Menu Bar Preview](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- Real-time usage limits from Anthropic API (Session 5h, Weekly All, Weekly Sonnet)
- Rolling window progress bars matching Claude's actual usage system
- Shows I/O tokens, cost, and usage percentage in the menu bar
- Today and Yesterday usage breakdown
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

## Understanding Cost Estimates

The estimated cost includes all token types charged by Anthropic:

| Token Type | Rate (Opus) | Description |
|---|---|---|
| Input | $15/MTok | Your messages sent to Claude |
| Output | $75/MTok | Claude's responses |
| Cache Read | $1.50/MTok | Re-reading cached conversation context |
| Cache Creation | $18.75/MTok | Creating new cache entries |

**Why does cost seem high?** Each message in a long session re-reads the full growing context from cache. So the longer the session, the more cache tokens accumulate — a 100-message session reads the entire conversation history 100 times from cache. Cache reads are cheap ($1.50/MTok vs $15/MTok for regular input), but they add up over long sessions and are the largest contributor to total cost.

## Adding a New Provider

1. Create a new class implementing the `UsageProvider` protocol
2. Add pricing to `LLMProviderType`
3. Register it in `UsageViewModel.init()`

## License

MIT
