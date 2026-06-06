# switch-settings

一键切换 Claude Code `settings.json` 配置的小工具。

## 原理

通过 `mv` 在多个 `settings.json.<name>` 文件之间轮换：

```
mv settings.json          → settings.json.<当前profile名>
mv settings.json.<目标名> → settings.json
```

纯 `mv` 轮换，不创建新文件。

## 用法

```bash
# 列出所有配置
./switch.sh

# 显示当前配置
./switch.sh --current

# 切换（支持子串匹配）
./switch.sh seek          # 精确匹配后缀 → seek
./switch.sh deep          # 子串匹配模型名 deepseek-v4-pro → seek
./switch.sh qwen          # 子串匹配模型名 qwen3.6-plus → qwen3.6-plus
./switch.sh mimo          # 精确匹配后缀 → mimo
```

## 子串匹配规则

输入关键词会同时匹配 **profile 后缀名** 和 **模型名**：

| 输入 | 匹配到 | 原因 |
|---|---|---|
| `seek` | seek | 后缀精确匹配 |
| `deep` | seek | 模型名 `deepseek-v4-pro` 包含 deep |
| `mimo` | mimo | 后缀精确匹配 |
| `v2` | mimo | 模型名 `mimo-v2-pro` 包含 v2 |
| `qwen` | qwen3.6-plus | 模型名包含 qwen |

如果关键词匹配到多个配置，会提示歧义并要求更精确地指定。

## 配置文件

| 文件名 | Provider | 模型 |
|---|---|---|
| `settings.json` | 当前激活 | — |
| `settings.json.mimo` | Mimo | mimo-v2-pro |
| `settings.json.seek` | DeepSeek | deepseek-v4-pro |

> 正在使用的配置会被 `mv` 成 `settings.json`，所以其对应的 `.json.<name>` 文件不存在。

## 环境变量

| 变量 | 说明 | 默认值 |
|---|---|---|
| `CLAUDE_SWITCH_DIR` | Claude 配置目录 | `~/.claude` |
