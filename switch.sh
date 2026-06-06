#!/bin/bash
#
# switch-settings — 一键切换 Claude Code settings.json 配置
#
# Usage:
#   ./switch.sh              # 列出所有可用配置
#   ./switch.sh <name>       # 切换到指定配置（支持子串匹配）
#   ./switch.sh --list       # 列出所有可用配置
#   ./switch.sh --current    # 显示当前激活的配置
#

set -euo pipefail

CLAUDE_DIR="${CLAUDE_SWITCH_DIR:-$HOME/.claude}"
ACTIVE_FILE="$CLAUDE_DIR/settings.json"
PREFIX="settings.json."

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ---------- helpers ----------

# 从 json 文件中读取 ANTHROPIC_MODEL
get_model() {
  if [ ! -f "$1" ]; then
    echo ""
    return
  fi
  if command -v jq &>/dev/null; then
    jq -r '.env.ANTHROPIC_MODEL // ""' "$1" 2>/dev/null || echo ""
  elif command -v python3 &>/dev/null; then
    python3 -c "
import json
with open('$1') as f:
    d = json.load(f)
print(d.get('env',{}).get('ANTHROPIC_MODEL','') or '')
" 2>/dev/null || echo ""
  else
    grep -o '"ANTHROPIC_MODEL"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" \
      | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || echo ""
  fi
}

# 扫描所有 profile，输出 "后缀名=模型名"
scan_profiles() {
  for f in "$CLAUDE_DIR"/${PREFIX}*; do
    [ -f "$f" ] || continue
    local name
    name="$(basename "$f")"
    name="${name#$PREFIX}"
    [ "$name" = "local" ] && continue
    local model
    model="$(get_model "$f")"
    echo "${name}=${model}"
  done
}

# 用子串匹配查找 profile
# 匹配规则：输入是 profile 后缀 或 模型名 的子串即可
# 返回匹配到的 profile 后缀名
find_profile() {
  local input="$1"
  local matched=""
  local count=0

  while IFS='=' read -r name model; do
    [ -z "$name" ] && continue
    # 精确匹配优先
    if [ "$name" = "$input" ]; then
      echo "$name"
      return
    fi
    # 子串匹配
    if [[ "$name" == *"$input"* ]] || [[ "$model" == *"$input"* ]]; then
      matched="$name"
      count=$((count + 1))
    fi
  done < <(scan_profiles)

  if [ "$count" -eq 1 ]; then
    echo "$matched"
  elif [ "$count" -gt 1 ]; then
    echo -e "${RED}错误: '$input' 匹配到多个配置，请更精确地指定${NC}" >&2
    echo "" >&2
    scan_profiles | while IFS='=' read -r name model; do
      [ -z "$name" ] && continue
      echo "    $name (模型: $model)" >&2
    done
    return 1
  fi
  return 1
}

# 找出当前 settings.json 对应的 profile 后缀
current_profile_name() {
  if [ ! -f "$ACTIVE_FILE" ]; then
    echo ""
    return
  fi
  local model
  model="$(get_model "$ACTIVE_FILE")"
  if [ -z "$model" ]; then
    echo ""
    return
  fi
  # 在 settings.json.* 中找同模型的
  while IFS='=' read -r name m; do
    if [ "$m" = "$model" ]; then
      echo "$name"
      return
    fi
  done < <(scan_profiles)
  # 找不到说明当前配置正在使用，用模型名作 profile 名
  echo "$model"
}

# ---------- commands ----------

do_list() {
  local current
  current="$(current_profile_name)"

  echo -e "当前配置: ${CYAN}${current:-无}${NC}"
  echo ""
  echo "可用配置:"
  local found=0
  while IFS='=' read -r name model; do
    [ -z "$name" ] && continue
    found=1
    if [ "$name" = "$current" ]; then
      echo -e "  ${GREEN}● $name${NC} (${model})"
    else
      echo -e "    $name (${model})"
    fi
  done < <(scan_profiles)
  if [ "$found" -eq 0 ]; then
    echo -e "  ${RED}没有发现任何配置${NC}"
  fi
}

do_current() {
  local current
  current="$(current_profile_name)"
  echo -e "${CYAN}${current:-无}${NC}"
}

do_switch() {
  local input="$1"
  local profile
  profile="$(find_profile "$input")" || exit 1

  if [ -z "$profile" ]; then
    echo -e "${RED}错误: 没有找到匹配 '$input' 的配置${NC}"
    echo "可用配置:"
    scan_profiles | while IFS='=' read -r name model; do
      [ -z "$name" ] && continue
      echo "    $name (${model})"
    done
    exit 1
  fi

  local target_file="$CLAUDE_DIR/$PREFIX$profile"

  if [ ! -f "$ACTIVE_FILE" ]; then
    mv "$target_file" "$ACTIVE_FILE"
    echo -e "${GREEN}已切换到: $profile${NC}"
    return
  fi

  local current
  current="$(current_profile_name)"
  if [ -n "$current" ]; then
    mv "$ACTIVE_FILE" "$CLAUDE_DIR/${PREFIX}${current}"
  else
    local model
    model="$(get_model "$ACTIVE_FILE")"
    echo -e "${YELLOW}警告: 模型 '$model' 没有对应的 profile，将丢弃当前配置${NC}"
    rm "$ACTIVE_FILE"
  fi

  mv "$target_file" "$ACTIVE_FILE"
  echo -e "${GREEN}已切换到: $profile${NC}"
}

# ---------- main ----------

if [ $# -eq 0 ]; then
  do_list
  echo ""
  echo "使用: $0 <关键词>  切换到匹配的配置"
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
    echo "用法: $0 [选项] [关键词]"
    echo ""
    echo "选项:"
    echo "  -l, --list      列出所有可用配置"
    echo "  -c, --current   显示当前配置"
    echo "  -h, --help      显示帮助"
    echo ""
    echo "关键词支持子串匹配（profile 名 或 模型名）"
    ;;
  *)
    do_switch "$1"
    ;;
esac
