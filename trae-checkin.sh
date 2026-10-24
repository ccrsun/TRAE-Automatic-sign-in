#!/usr/bin/env bash
# Trae 每日签到启动脚本
# 用法：./trae-checkin.sh
# 凭证从同目录 trae-checkin.env 读取，日志追加到 ~/trae_checkin.log
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${TRAE_CHECKIN_ENV:-$SCRIPT_DIR/trae-checkin.env}"
LOG_FILE="${TRAE_CHECKIN_LOG:-$HOME/trae_checkin.log}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "缺少凭证文件: $ENV_FILE" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# cron 的 PATH 很窄，这里兜底查找 python3（也可在 env 文件里指定 TRAE_CHECKIN_PYTHON）
PYTHON_BIN="${TRAE_CHECKIN_PYTHON:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  for candidate in python3 /usr/local/bin/python3 /opt/homebrew/bin/python3 /usr/bin/python3; do
    if command -v "$candidate" >/dev/null 2>&1; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
fi
if [[ -z "$PYTHON_BIN" ]]; then
  echo "未找到 python3，请在 $ENV_FILE 中设置 TRAE_CHECKIN_PYTHON" >&2
  exit 1
fi

set +e
{
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
  cd "$SCRIPT_DIR"
  "$PYTHON_BIN" checkin.py
} 2>&1 | tee -a "$LOG_FILE"
status=${PIPESTATUS[0]}
set -e

# 退出码 2 = Session 失效，需要重新登录后更新凭证
if [[ $status -eq 2 ]]; then
  echo "Session 已失效：请重新登录 Trae 获取 X-Cloudide-Session 并更新 $ENV_FILE" | tee -a "$LOG_FILE"
fi
exit "$status"
