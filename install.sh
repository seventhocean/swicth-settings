#!/bin/bash
#
# 一键安装/更新 switch-settings
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/seventhocean/swicth-settings/main/install.sh | bash
#

set -euo pipefail

REPO_URL="https://github.com/seventhocean/swicth-settings.git"
INSTALL_DIR="$HOME/.switch-settings"
BIN_NAME="switch"
LINK_PATH="/usr/local/bin/$BIN_NAME"

echo "==> 安装/更新 switch-settings..."

# 克隆或更新仓库
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "==> 更新现有仓库..."
  (cd "$INSTALL_DIR" && git pull --ff-only 2>/dev/null || echo "    已是最新版本")
else
  echo "==> 克隆仓库到 $INSTALL_DIR..."
  [ -d "$INSTALL_DIR" ] && rm -rf "$INSTALL_DIR"
  git clone --quiet "$REPO_URL" "$INSTALL_DIR"
fi

# 创建软链接
echo "==> 创建软链接到 $LINK_PATH..."
ln -sf "$INSTALL_DIR/switch.sh" "$LINK_PATH"

echo ""
echo "==> 安装完成！使用 switch 命令切换配置："
echo "    switch           # 列出配置"
echo "    switch <关键词>  # 切换配置"
