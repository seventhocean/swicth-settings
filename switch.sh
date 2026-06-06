#!/bin/bash
#
# switch-settings — 一键切换 Claude Code settings.json 配置
#
# Usage:
#   ./switch.sh              # 列出所有可用配置
#   ./switch.sh <name>       # 切换到指定配置
#   ./switch.sh --list       # 列出所有可用配置
#   ./switch.sh --current    # 显示当前激活的配置
#   ./switch.sh --init       # 初始化：扫描配置文件，建立模型名→后缀名映射
#

set -euo pipefail

CLAUDE_DIR="${CLAUDE_SWITCH_DIR:-$HOME/.claude}"
ACTIVE_FILE="$CLAUDE_DIR/settings.json"
PREFIX="settings.json."

# 映射文件路径（脚本同目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAP_FILE="$SCRIPT_DIR/.profiles.json"

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

# 从 settings.json.* 文件后缀获取可用配置名（排除 local）
available_profiles() {
  local dir="$1"
  for f in "$dir"/${PREFIX}*; do
    [ -f "$f" ] || continue
    local name
    name="$(basename "$f")"
    name="${name#$PREFIX}"
    [ "$name" = "local" ] && continue
    echo "$name"
  done
}

# ---------- commands ----------

do_init() {
  echo -e "${CYAN}扫描 $CLAUDE_DIR 下的配置文件...${NC}"

  # 构建映射: { "模型名": "profile后缀名" }
  local json="{"
  local first=1

  # 先扫 settings.json.* 文件
  for f in "$CLAUDE_DIR"/${PREFIX}*; do
    [ -f "$f" ] || continue
    local name
    name="$(basename "$f")"
    name="${name#$PREFIX}"
    [ "$name" = "local" ] && continue
    local model
    model="$(get_model "$f")"
    if [ -n "$model" ]; then
      if [ "$first" -eq 0 ]; then
        json="$json,"
      fi
      json="$json\"$model\":\"$name\""
      first=0
    fi
  done

  # 再扫当前 settings.json（它没有对应的 .<name> 文件，用模型名作 profile 名）
  if [ -f "$ACTIVE_FILE" ]; then
    local model
    model="$(get_model "$ACTIVE_FILE")"
    if [ -n "$model" ] && [[ "$json" != *"\"$model\":"* ]]; then
      if [ "$first" -eq 0 ]; then
        json="$json,"
      fi
      json="$json\"$model\":\"$model\""
    fi
  fi
  json="$json}"

  echo "$json" | if command -v jq &>/dev/null; then
    jq '.'
  else
    cat
  fi > "$MAP_FILE"

  echo ""
  echo -e "${GREEN}已生成映射文件: $MAP_FILE${NC}"
  echo -e "${YELLOW}提示: 可编辑 $MAP_FILE 将 profile 名改为短别名（如 plus）${NC}"
  echo ""
  echo "可用配置:"
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    echo -e "    $p"
  done < <(available_profiles "$CLAUDE_DIR")
}

# 加载映射文件
load_map() {
  if [ ! -f "$MAP_FILE" ]; then
    echo -e "${RED}错误: 映射文件不存在，请先运行 ./switch.sh --init${NC}"
    exit 1
  fi

  if command -v jq &>/dev/null; then
    # 读取映射到关联数组
    while IFS='=' read -r key val; do
      MODEL_MAP["$key"]="$val"
    done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$MAP_FILE" 2>/dev/null)
  elif command -v python3 &>/dev/null; then
    while IFS='=' read -r key val; do
      MODEL_MAP["$key"]="$val"
    done < <(python3 -c "
import json
with open('$MAP_FILE') as f:
    d = json.load(f)
for k,v in d.items():
    print(f'{k}={v}')
" 2>/dev/null)
  else
    # 纯 bash 解析简单 JSON
    local content
    content="$(cat "$MAP_FILE")"
    content="${content#\{}"
    content="${content%\}}"
    content="${content//\"/}"
    content="${content// /}"
    IFS=',' read -ra pairs <<< "$content"
    for pair in "${pairs[@]}"; do
      IFS=':' read -r key val <<< "$pair"
      MODEL_MAP["$key"]="$val"
    done
  fi
}

declare -A MODEL_MAP

# 根据模型名找 profile
model_to_profile() {
  echo "${MODEL_MAP[$1]:-}"
}

# 找出当前 settings.json 对应的 profile
current_profile() {
  if [ ! -f "$ACTIVE_FILE" ]; then
    echo ""
    return
  fi
  local model
  model="$(get_model "$ACTIVE_FILE")"
  if [ -n "$model" ]; then
    model_to_profile "$model"
  else
    echo ""
  fi
}

do_list() {
  load_map
  local profile
  profile="$(current_profile)"

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
  done < <(available_profiles "$CLAUDE_DIR")
  if [ "$found" -eq 0 ]; then
    echo -e "  ${RED}没有发现任何配置${NC}"
  fi
}

do_current() {
  load_map
  local profile
  profile="$(current_profile)"
  echo -e "${CYAN}${profile:-无}${NC}"
}

do_switch() {
  local target="$1"
  local target_file="$CLAUDE_DIR/$PREFIX$target"

  if [ ! -f "$target_file" ]; then
    echo -e "${RED}错误: 配置 '$target' 不存在${NC}"
    echo "可用配置:"
    available_profiles "$CLAUDE_DIR"
    exit 1
  fi

  if [ ! -f "$ACTIVE_FILE" ]; then
    mv "$target_file" "$ACTIVE_FILE"
    echo -e "${GREEN}已切换到: $target${NC}"
    return
  fi

  load_map
  local profile
  profile="$(current_profile)"

  if [ -n "$profile" ]; then
    mv "$ACTIVE_FILE" "$CLAUDE_DIR/${PREFIX}${profile}"
  else
    local model
    model="$(get_model "$ACTIVE_FILE")"
    echo -e "${YELLOW}警告: 模型 '$model' 没有对应的 profile，将丢弃当前配置${NC}"
    rm "$ACTIVE_FILE"
  fi

  mv "$target_file" "$ACTIVE_FILE"
  echo -e "${GREEN}已切换到: $target${NC}"
}

# ---------- main ----------

if [ $# -eq 0 ]; then
  if [ ! -f "$MAP_FILE" ]; then
    echo -e "${YELLOW}未初始化，请先运行 ./switch.sh --init${NC}"
    exit 1
  fi
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
  -i|--init)
    do_init
    ;;
  -h|--help)
    echo "用法: $0 [选项] [配置名]"
    echo ""
    echo "选项:"
    echo "  -i, --init      初始化：扫描配置，建立模型→profile 映射"
    echo "  -l, --list      列出所有可用配置"
    echo "  -c, --current   显示当前配置"
    echo "  -h, --help      显示帮助"
    ;;
  *)
    do_switch "$1"
    ;;
esac
