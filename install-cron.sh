#!/usr/bin/env bash
# 安装 Trae 自动签到定时任务（可重复执行，不会覆盖其它 cron 任务）
# 默认每天 00:05 执行；可用 TRAE_CHECKIN_SCHEDULE 覆盖，例如：
#   TRAE_CHECKIN_SCHEDULE='30 7 * * *' ./install-cron.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/trae-checkin.sh"
SCHEDULE="${TRAE_CHECKIN_SCHEDULE:-5 0 * * *}"
MARKER="# trae-checkin"

if ! command -v crontab >/dev/null 2>&1; then
  echo "未找到 crontab，请先安装 cron（Debian/Ubuntu: sudo apt install cron；macOS 自带 cron）" >&2
  exit 1
fi

chmod +x "$RUNNER"
LINE="$SCHEDULE $RUNNER $MARKER"

# 先删除旧的同标记任务，再追加新任务
{ crontab -l 2>/dev/null | grep -vF "$MARKER" || true; echo "$LINE"; } | crontab -

echo "已安装定时任务："
echo "  $LINE"
echo "查看当前任务：crontab -l"
echo "日志位置：${TRAE_CHECKIN_LOG:-$HOME/trae_checkin.log}"
