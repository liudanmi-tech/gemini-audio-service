#!/bin/bash
# 查看服务端日志，定位任务列表超时问题
# 用法：./查看服务端日志并诊断.sh
# 输出保存到 服务器日志_诊断.txt
# 注意：需先部署带增强日志的 main.py 和 auth/jwt_handler.py，再复现超时，然后执行本脚本

SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
OUTPUT="服务器日志_诊断.txt"

echo "========== 查看服务端日志并诊断 =========="
echo "服务器: $SERVER"
echo "输出: $OUTPUT"
echo ""

if ! ssh -o ConnectTimeout=25 "$SERVER" bash << 'REMOTE' 2>&1 | tee "$OUTPUT"
set -e

echo "=== 1. 应用进程与端口 ==="
ss -tlnp 2>/dev/null | grep -E '8000|8001' || echo "无 8000/8001 监听"
ps aux | grep -E "uvicorn|main.py" | grep -v grep || true

echo ""
echo "=== 2. 最近 300 行日志（含 Request/Response/任务列表/Auth）==="
tail -300 ~/gemini-audio-service.log 2>/dev/null | grep -E "\[Request\]|\[Response\]|\[任务列表\]|\[Auth\]|ERROR|WARNING|502|504|timeout" || tail -100 ~/gemini-audio-service.log

echo ""
echo "=== 3. tasks/sessions 相关日志 ==="
grep -E "tasks/sessions|任务列表" ~/gemini-audio-service.log 2>/dev/null | tail -30 || echo "无匹配"

echo ""
echo "=== 4. auth/me 相关（认证慢）==="
grep -E "auth/me|Auth.*User 查询" ~/gemini-audio-service.log 2>/dev/null | tail -20 || echo "无匹配"

echo ""
echo "=== 5. Nginx 超时配置 ==="
grep -E "proxy_.*_timeout" /etc/nginx/sites-available/* /etc/nginx/sites-enabled/* 2>/dev/null || echo "未找到"

echo ""
echo "=== 6. 数据库连接（RDS 慢会导致请求卡住）==="
grep -E "DATABASE_URL|数据库|SSL|连接" ~/gemini-audio-service/.env 2>/dev/null | sed 's/:.*@/:****@/' | head -5 || echo "无 .env 或无可读配置"
REMOTE
then
  echo ""
  echo "❌ SSH 连接失败。可在服务器上直接执行以下命令并查看输出："
  echo ""
  echo "  tail -300 ~/gemini-audio-service.log | grep -E 'Request|Response|任务列表|Auth|ERROR'"
  echo "  grep 'tasks/sessions\|任务列表' ~/gemini-audio-service.log | tail -30"
  exit 1
fi

echo ""
echo "========== 诊断完成 =========="
echo "日志已保存到: $OUTPUT"
echo ""
echo "常见超时原因："
echo "  1. [Request] 有但无 [Response] → 请求卡在应用内（DB/认证）"
echo "  2. [Auth] User 查询耗时长 → 数据库连接或 RDS 慢"
echo "  3. [任务列表] Session 查询耗时长 → 缺索引或 RDS 慢"
echo "  4. 完全无 [Request] → 请求未到应用（Nginx/网络/防火墙）"
echo "  5. Nginx proxy_read_timeout 60s → 需改为 120s 或更长"
