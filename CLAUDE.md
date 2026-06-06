# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository: switch-settings

## Project Overview

A Shell utility to switch between multiple Claude Code `settings.json` configurations by rotating files with `mv`.

## Commands

```bash
./switch.sh              # 列出所有配置
./switch.sh --list       # 同上
./switch.sh --current    # 显示当前配置
./switch.sh seek         # 切换（子串匹配 profile 名或模型名）
```

## Architecture

### How it works

The tool operates on `~/.claude/settings.json*` files:

- `settings.json` — the active configuration (Claude Code reads this)
- `settings.json.<name>` — inactive profiles (e.g., `.mimo`, `.seek`)

Switching is a simple `mv` rotation:
1. `mv settings.json → settings.json.<当前profile名>`
2. `mv settings.json.<目标名> → settings.json`

### Profile matching

No mapping file needed. Switching uses **substring matching** against both the profile suffix and the `ANTHROPIC_MODEL` value in each config file:

- `./switch.sh seek` → matches suffix `seek` → `settings.json.seek`
- `./switch.sh deep` → matches model `deepseek-v4-pro` → `settings.json.seek`
- `./switch.sh qwen` → matches model `qwen3.6-plus` → `settings.json.qwen3.6-plus`

If a keyword matches multiple profiles, an ambiguity error is shown.

### Key design decisions

- **No mapping files** — dynamically reads model names from JSON files
- **Excludes `settings.json.local`** from the available profiles list
- **Pure `mv`** (not `cp`) — the current config is always saved back, nothing is lost
- **Portable** — works on any machine with any set of `settings.json.*` files

### File structure

```
switch.sh              # The switch utility (bash)
README.md              # Project documentation
CLAUDE.md              # This file
```
