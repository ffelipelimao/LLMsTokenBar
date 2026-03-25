# LLMsTokenBar

A native macOS menu bar app that tracks your LLM token usage and estimated cost in real-time.

![Menu Bar Preview](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- Shows I/O tokens, cost, and daily limit percentage in the menu bar
- Progress bar with color-coded usage indicator (green/orange/red)
- Today and Yesterday usage breakdown
- Configurable plan limits (Pro, Max $100/mo, Max $200/mo, Custom)
- Auto-refresh via directory watcher + 60s timer
- Extensible provider architecture for future LLM providers

## Supported Providers

- **Claude Code** — reads session data from `~/.claude/projects/` JSONL files

## Requirements

- macOS 14.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Build

```bash
brew install xcodegen
cd LLMsTokenBar
xcodegen generate
open LLMsTokenBar.xcodeproj
```

Build and run with `Cmd+R`. The app appears in the menu bar (no Dock icon).

## Adding a New Provider

1. Create a new class implementing the `UsageProvider` protocol
2. Add pricing to `LLMProviderType`
3. Register it in `UsageViewModel.init()`

## License

MIT
