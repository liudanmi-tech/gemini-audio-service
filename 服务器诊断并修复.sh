#!/bin/bash
# 在服务器上执行：诊断并修复 API 无响应问题
# 用法：ssh admin@47.79.254.213 'bash -s' < 服务器诊断并修复.sh
# 或：复制此脚本到服务器后执行 bash 服务器诊断并修复.sh

set -e
cd ~/gemini-audio-service 2>/dev/null || cd /home/admin/gemini-audio-service 2>/dev/null || true

echo "========== 1. 进程检查 =========="
pgrep -af "main.py|uvicorn" || echo "⚠️ 无 Python 后端进程"

echo ""
echo "========== 2. 端口检查 =========="
ss -tlnp 2>/dev/null | grep -E "8000|80" || netstat -tlnp 2>/dev/null | grep -E "8000|80" || echo "未找到 8000 端口监听"

echo ""
echo "========== 3. 本地 API 测试 =========="
curl -s -m 10 "http://127.0.0.1:8000/" 2>/dev/null && echo "" || echo "⚠️ 本地 8000 无响应"
curl -s -m 10 "http://127.0.0.1:8000/api/v1/auth/send-code" -X POST -H "Content-Type: application/json" -d '{"phone":"13800138000"}' 2>/dev/null | head -c 200
echo ""

echo ""
echo "========== 4. 最近日志（最后 30 行）=========="
tail -30 ~/gemini-audio-service.log 2>/dev/null || tail -30 /home/admin/gemini-audio-service.log 2>/dev/null

echo ""
echo "========== 5. 重启服务 =========="
pkill -f "uvicorn main" 2>/dev/null || true
pkill -f "python.*main" 2>/dev/null || true
sleep 3
nohup venv/bin/python3 main.py >> ~/gemini-audio-service.log 2>&1 &
echo "已启动 main.py，等待 15 秒..."
sleep 15

echo ""
echo "========== 6. 重启后验证 =========="
curl -s -m 10 "http://127.0.0.1:8000/" 2>/dev/null && echo " ✓ 根路径 OK" || echo " ✗ 根路径失败"
curl -s -m 10 "http://127.0.0.1:8000/api/v1/auth/send-code" -X POST -H "Content-Type: application/json" -d '{"phone":"13800138000"}' 2>/dev/null | head -c 150
echo ""
echo ""
echo "========== 完成 =========="
echo "若本地 API 正常，可从外网访问: curl -X POST http://47.79.254.213/api/v1/auth/send-code -H 'Content-Type: application/json' -d '{\"phone\":\"13800138000\"}'"
