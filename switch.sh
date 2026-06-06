#!/bin/bash
#
# switch-settings — 一键切换 Claude Code settings.json 配置
#
# Usage:
#   ./switch.sh              # 列出所有可用配置
#   ./switch.sh <name>       # 切换到指定配置
#   ./switch.sh --list       # 列出所有可用配置
#   ./switch.sh --current    # 显示当前激活的配置
#

set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
ACTIVE_FILE="$CLAUDE_DIR/settings.json"
PREFIX="settings.json."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------- helpers ----------

# 从 settings.json 中读取 ANTHROPIC_MODEL
get_model() {
  if [ ! -f "$1" ]; then
    echo ""
    return
  fi
  python3 -c "
import json
with open('$1') as f:
    d = json.load(f)
print(d.get('env',{}).get('ANTHROPIC_MODEL','') or '')
" 2>/dev/null || echo ""
}

# 从 settings.json.* 文件后缀获取可用配置名（排除 local）
available_profiles() {
  for f in "$CLAUDE_DIR"/${PREFIX}*; do
    [ -f "$f" ] || continue
    local name
    name="$(basename "$f")"
    name="${name#$PREFIX}"
    # 排除 local
    [ "$name" = "local" ] && continue
    echo "$name"
  done
}

# Model → profile 短后缀映射
declare -A MODEL_TO_PROFILE=(
  ["qwen3.6-plus"]="plus"
  ["mimo-v2-pro"]="mimo"
  ["deepseek-v4-pro"]="seek"
  ["deepseek-v4-pro[1M]"]="seek"
  ["mimo-v2.5-pro"]="mimo"
)

# 根据模型名找到对应的短后缀 profile
model_to_profile() {
  local model="$1"
  if [ -n "$model" ] && [ -n "${MODEL_TO_PROFILE[$model]+x}" ]; then
    echo "${MODEL_TO_PROFILE[$model]}"
  else
    echo ""
  fi
}

# ---------- commands ----------

do_list() {
  local model
  model="$(get_model "$ACTIVE_FILE")"
  local profile
  profile="$(model_to_profile "$model")"

  echo -e "当前配置: ${CYAN}${profile:-无}${NC}"
  echo ""
  echo "可用配置:"
  local found=0
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    found=1
    if [ "$p" = "$profile" ]; then
      echo -e "  ${GREEN}● $p${NC}"
    else
      echo -e "    $p"
    fi
  done < <(available_profiles)
  if [ "$found" -eq 0 ]; then
    echo -e "  ${RED}没有发现任何配置${NC}"
  fi
}

do_current() {
  local model
  model="$(get_model "$ACTIVE_FILE")"
  local profile
  profile="$(model_to_profile "$model")"
  echo -e "${CYAN}${profile:-无}${NC}"
}

do_switch() {
  local target="$1"
  local target_file="$CLAUDE_DIR/$PREFIX$target"

  # 检查目标文件存在
  if [ ! -f "$target_file" ]; then
    echo -e "${RED}错误: 配置 '$target' 不存在${NC}"
    echo "可用配置:"
    available_profiles
    exit 1
  fi

  # 把当前 settings.json mv 回对应的 profile 文件
  if [ -f "$ACTIVE_FILE" ]; then
    local model
    model="$(get_model "$ACTIVE_FILE")"
    if [ -n "$model" ]; then
      local profile
      profile="$(model_to_profile "$model")"
      if [ -n "$profile" ]; then
        mv "$ACTIVE_FILE" "$CLAUDE_DIR/${PREFIX}${profile}"
      else
        rm "$ACTIVE_FILE"
      fi
    else
      rm "$ACTIVE_FILE"
    fi
  fi

  # 把目标配置 mv 成 settings.json
  mv "$target_file" "$ACTIVE_FILE"

  echo -e "${GREEN}已切换到: $target${NC}"
}

# ---------- main ----------

if [ $# -eq 0 ]; then
  do_list
  echo ""
  echo "使用: $0 <name>  切换到指定配置"
  exit 0
fi

case "$1" in
  -l|--list)
    do_list
    ;;
  -c|--current)
    do_current
    ;;
  -h|--help)
    echo "用法: $0 [选项] [配置名]"
    echo ""
    echo "选项:"
    echo "  -l, --list      列出所有可用配置"
    echo "  -c, --current   显示当前配置"
    echo "  -h, --help      显示帮助"
    ;;
  *)
    do_switch "$1"
    ;;
esac
