#!/usr/bin/env bash
# Trae 每日签到包装脚本
# - 加载 /workspace/trae-checkin.env 凭证
# - 运行 checkin.py，输出追加到 ~/trae_checkin.log（自动轮转 500 行）
# - Session 失效（GetUserToken 失败）时退出码 2，并打标 ~/.trae_checkin.need_login
# - 环境文件缺失 / Python 缺失 时退出码 1
# - cron 用法：0 8 * * * /workspace/trae-checkin.sh
set -u

ENV_FILE="/workspace/trae-checkin.env"
PY_SCRIPT="/workspace/checkin.py"
LOG_FILE="${HOME}/trae_checkin.log"
NEED_LOGIN_FLAG="${HOME}/.trae_checkin.need_login"
LOG_MAX_LINES=500

rotated=0
rotated_msg() {
    local n=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    echo "（日志已轮转，原行数=$n）"
}
rotate_log_if_needed() {
    [ -f "$LOG_FILE" ] || return 0
    local lines
    lines=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$lines" -gt "$LOG_MAX_LINES" ]; then
        local keep=$((LOG_MAX_LINES - 200))
        head -n "$keep" "$LOG_FILE" > "${LOG_FILE}.rotated"
        mv "${LOG_FILE}.rotated" "$LOG_FILE"
        rotated=1
    fi
}
ts() { date '+%Y-%m-%d %H:%M:%S'; }

# 确保日志目录存在
mkdir -p "$(dirname "$LOG_FILE")"

# Python 检测
PY_BIN="python3"
command -v "$PY_BIN" >/dev/null 2>&1 || PY_BIN="python"
if ! command -v "$PY_BIN" >/dev/null 2>&1; then
    {
        echo "===== $(ts) (exit=1) ====="
        echo "错误：未找到 python3 / python"
    } >> "$LOG_FILE"
    exit 1
fi

# checkin.py 检测
if [ ! -f "$PY_SCRIPT" ]; then
    {
        echo "===== $(ts) (exit=1) ====="
        echo "错误：签到脚本 $PY_SCRIPT 不存在"
    } >> "$LOG_FILE"
    exit 1
fi

# 加载凭证（set -a 自动 export）
if [ -f "$ENV_FILE" ]; then
    # 收紧权限：env 含凭证，不应全局可读
    chmod 600 "$ENV_FILE" 2>/dev/null || true
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
else
    {
        echo "===== $(ts) (exit=1) ====="
        echo "错误：凭证文件 $ENV_FILE 不存在"
    } >> "$LOG_FILE"
    exit 1
fi

# Session 必须非空
if [ -z "${TRAE_SESSION:-}" ]; then
    {
        echo "===== $(ts) (exit=1) ====="
        echo "错误：TRAE_SESSION 为空"
    } >> "$LOG_FILE"
    exit 1
fi

# 运行签到，合并 stdout/stderr
OUTPUT=$("$PY_BIN" "$PY_SCRIPT" 2>&1)
EXIT_CODE=$?

# 判断是否为 Session 失效：
# - checkin.py 在 Session 无效时输出 "GetUserToken 失败"
# - 本脚本前面 Session 为空已 exit 1，这里只需识别 GetUserToken 失败
NEED_LOGIN=0
if echo "$OUTPUT" | grep -qiE "GetUserToken 失败|Session 已失效"; then
    NEED_LOGIN=1
fi

rotate_log_if_needed

{
    echo "===== $(ts) (exit=$EXIT_CODE) ====="
    [ "$rotated" -eq 1 ] && rotated_msg
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

# 成功则清除 need_login 标记
if [ "$EXIT_CODE" -eq 0 ] && [ -f "$NEED_LOGIN_FLAG" ]; then
    rm -f "$NEED_LOGIN_FLAG"
fi

exit "$EXIT_CODE"
