# switch-settings

一键切换 Claude Code `settings.json` 配置的小工具。

## 使用场景

你有多个 Claude Code provider 配置，保存在 `~/.claude/settings.json.<name>` 文件中。此工具通过 `mv` 在它们之间轮换，实现一键切换。

## 用法

```bash
# 列出所有可用配置
./switch.sh
./switch.sh --list

# 显示当前配置
./switch.sh --current

# 切换到指定配置
./switch.sh mimo
./switch.sh seek
./switch.sh plus
```

## 原理

```
mv settings.json          → settings.json.<当前profile名>
mv settings.json.<目标名> → settings.json
```

纯 `mv` 轮换，不创建新文件，只在已有的配置文件之间切换。

## 首次使用

换到新机器或新增/删除配置后，需要先初始化：

```bash
./switch.sh --init
```

这会扫描 `~/.claude/settings.json*` 文件，生成 `.profiles.json` 映射文件（模型名 → profile 短名）。生成后可编辑该文件自定义 profile 名称。

## 配置文件

| Profile | 文件名 | Provider | 模型 |
|---|---|---|---|
| `plus` | `settings.json.plus` | 阿里云百炼 | qwen3.6-plus |
| `mimo` | `settings.json.mimo` | Mimo | mimo-v2-pro |
| `seek` | `settings.json.seek` | DeepSeek | deepseek-v4-pro |

> 正在使用的配置会被 `mv` 成 `settings.json`，所以其对应的 `settings.json.<name>` 文件不存在。
