#!/bin/bash
# 在服务器上查看指定 session 的分析相关日志，用于定位失败原因
# 用法：在服务器上执行 bash check_session_log.sh <session_id>
# 或：ssh admin@47.79.254.213 "cd ~/gemini-audio-service && bash scripts/check_session_log.sh <session_id>"

SESSION_ID="${1:-d5a56cd0-8ef5-44d1-9001-b4dfe3402428}"
LOG_FILE="${2:-$HOME/gemini-audio-service.log}"

if [ ! -f "$LOG_FILE" ]; then
  echo "❌ 日志文件不存在: $LOG_FILE"
  exit 1
fi

echo "========== 查找 session 分析日志 =========="
echo "session_id: $SESSION_ID"
echo "日志文件: $LOG_FILE"
echo ""

echo "--- 1. 该 session 创建/上传/分析相关行 ---"
grep -n "$SESSION_ID" "$LOG_FILE" | head -80

echo ""
echo "--- 2. 分析失败块（若失败会有「分析音频失败」及后续错误）---"
grep -n "分析音频失败\|session_id: $SESSION_ID\|错误类型:\|错误信息:\|上传失败（第\|Connection refused\|Errno 111" "$LOG_FILE" | tail -100

echo ""
echo "--- 3. 最近 50 行含 ERROR 或 分析音频失败 的日志 ---"
grep -n "ERROR\|分析音频失败\|Connection refused\|上传文件失败" "$LOG_FILE" | tail -50
