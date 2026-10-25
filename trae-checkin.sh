#!/usr/bin/env bash
# Trae 每日签到包装脚本
# - 加载 /workspace/trae-checkin.env 凭证
# - 运行 checkin.py，输出追加到 ~/trae_checkin.log
# - Session 失效（GetUserToken 失败）时退出码 2，并打标 ~/.trae_checkin.need_login
set -u

ENV_FILE="/workspace/trae-checkin.env"
PY_SCRIPT="/workspace/checkin.py"
LOG_FILE="${HOME}/trae_checkin.log"
NEED_LOGIN_FLAG="${HOME}/.trae_checkin.need_login"

# 加载凭证（set -a 自动 export）
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
else
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    {
        echo "===== $TS (exit=1) ====="
        echo "错误：凭证文件 $ENV_FILE 不存在"
    } >> "$LOG_FILE"
    exit 1
fi

# 运行签到，合并 stdout/stderr
OUTPUT=$(python3 "$PY_SCRIPT" 2>&1)
EXIT_CODE=$?

TS=$(date '+%Y-%m-%d %H:%M:%S')

# 判断是否为 Session 失效/缺失：
# - checkin.py 在 Session 无效时输出 "GetUserToken 失败"
# - TRAE_SESSION 为空时输出 "缺少环境变量 TRAE_SESSION"
NEED_LOGIN=0
if echo "$OUTPUT" | grep -qiE "GetUserToken 失败|缺少环境变量 TRAE_SESSION"; then
    NEED_LOGIN=1
fi

{
    echo "===== $TS (exit=$EXIT_CODE) ====="
    echo "$OUTPUT"
    if [ "$NEED_LOGIN" -eq 1 ]; then
        echo ">>> Session 已失效（X-Cloudide-Session 过期），需要重新登录"
    fi
    echo ""
} >> "$LOG_FILE"

if [ "$NEED_LOGIN" -eq 1 ]; then
    touch "$NEED_LOGIN_FLAG"
    echo "Session 已失效，请重新登录获取 X-Cloudide-Session" >&2
    exit 2
fi

# 非 Session 问题：成功则清除 need_login 标记
if [ "$EXIT_CODE" -eq 0 ] && [ -f "$NEED_LOGIN_FLAG" ]; then
    rm -f "$NEED_LOGIN_FLAG"
fi

exit "$EXIT_CODE"
