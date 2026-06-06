# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository: switch-settings

## Project Overview

A small Shell utility to switch between multiple Claude Code `settings.json` configurations by rotating files with `mv`.

## Commands

```bash
./switch.sh           # 列出所有可用配置
./switch.sh --list    # 同上
./switch.sh --current # 显示当前激活的配置
./switch.sh <name>    # 切换到指定配置（如 mimo、seek）
```

## Architecture

### How it works

The tool operates on `~/.claude/settings.json*` files:

- `settings.json` — the active configuration (Claude Code reads this)
- `settings.json.<name>` — inactive profiles (e.g., `.mimo`, `.seek`)

Switching is a simple `mv` rotation:
1. `mv settings.json → settings.json.<当前profile名>`
2. `mv settings.json.<目标名> → settings.json`

### Model to Profile mapping

The script maintains a mapping of `ANTHROPIC_MODEL` values to short profile names:

| Model | Profile | File |
|---|---|---|
| `qwen3.6-plus` | `plus` | `settings.json.plus` |
| `mimo-v2-pro` | `mimo` | `settings.json.mimo` |
| `deepseek-v4-pro` | `seek` | `settings.json.seek` |

To add a new profile:
1. Create `settings.json.<name>` with the desired config
2. Add the model→profile mapping in `switch.sh`

### Key design decisions

- **No new files created** — only rotates among existing `settings.json.*` files
- **Excludes `settings.json.local`** from the available profiles list
- **Pure `mv`** (not `cp`) — the current config is always saved back, nothing is lost

### File structure

```
switch.sh              # The switch utility (bash)
README.md              # Project documentation
CLAUDE.md              # This file
```
