#!/usr/bin/env bash
# Trae 每日签到包装脚本
# 读取 trae-checkin.env 中的凭证，运行 checkin.py，并按结果设置退出码：
#   0   签到成功
#   1   checkin.py 通用失败（非会话/风控）
#   2   Session 缺失或已失效（需要重新登录）
#   3   风控 9074（需要更换设备号）
set -u

ENV_FILE="/workspace/trae-checkin.env"
LOG_FILE="$HOME/trae_checkin.log"
NEED_LOGIN="$HOME/.trae_checkin.need_login"

# 加载凭证
if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

# 运行签到
OUTPUT=$(python3 /workspace/checkin.py 2>&1)
EXIT_CODE=$?

# 记录日志（带时间戳与退出码）
{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] exit_code=$EXIT_CODE"
  echo "$OUTPUT"
  echo "----"
} >> "$LOG_FILE"

# 判断 Session 是否失效/缺失
if echo "$OUTPUT" | grep -qiE "Session 已失效|GetUserToken 失败|缺少环境变量 TRAE_SESSION|Unauthorized|unauthorized"; then
  touch "$NEED_LOGIN"
  exit 2
fi

# 判断风控 9074
if echo "$OUTPUT" | grep -qi "9074"; then
  exit 3
fi

# 其他情况透传 checkin.py 退出码
exit "$EXIT_CODE"
