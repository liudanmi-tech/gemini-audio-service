#!/bin/bash
# 在服务器上执行，检查 session 是否写入/拉取了记忆
# 用法: bash 检查session记忆.sh 11d04236-d0cb-4642-a380-cfab349b07d8

SESSION_ID="${1:-11d04236-d0cb-4642-a380-cfab349b07d8}"
LOG="${LOG:-$HOME/gemini-audio-service.log}"

echo "=== 检查 session 记忆: $SESSION_ID ==="
echo ""

echo "--- 1. 服务端 [记忆] 日志（该 session 相关）---"
grep "$SESSION_ID" "$LOG" 2>/dev/null | grep "\[记忆\]" | tail -30
echo ""

echo "--- 2. 用 check_session_memory 脚本（需能连数据库）---"
cd ~/gemini-audio-service 2>/dev/null && source venv/bin/activate 2>/dev/null
python3 check_session_memory.py "$SESSION_ID" 2>/dev/null || echo "请在服务器上执行: python3 check_session_memory.py $SESSION_ID"
