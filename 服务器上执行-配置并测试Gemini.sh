#!/bin/bash
# 在阿里云 Workbench 执行：配置 Gemini 直连并测试连接
set -e
cd ~/gemini-audio-service

echo "========== 1. 配置 .env =========="
# 确保 GEMINI_FILE_UPLOAD_NO_PROXY=true（新加坡服务器可直连）
grep -q "GEMINI_FILE_UPLOAD_NO_PROXY" .env 2>/dev/null && \
  sed -i 's/^GEMINI_FILE_UPLOAD_NO_PROXY=.*/GEMINI_FILE_UPLOAD_NO_PROXY=true/' .env || \
  echo "GEMINI_FILE_UPLOAD_NO_PROXY=true" >> .env

# 确保上传超时 180 秒（64MB 大文件）
grep -q "GEMINI_UPLOAD_TIMEOUT" .env 2>/dev/null && \
  sed -i 's/^GEMINI_UPLOAD_TIMEOUT=.*/GEMINI_UPLOAD_TIMEOUT=180/' .env || \
  echo "GEMINI_UPLOAD_TIMEOUT=180" >> .env

echo "当前相关配置:"
grep -E "GEMINI_FILE_UPLOAD_NO_PROXY|GEMINI_UPLOAD_TIMEOUT" .env || true
echo ""

echo "========== 2. 测试 Gemini 连接 =========="
source venv/bin/activate
python3 scripts/test_gemini_connection.py
echo ""

echo "========== 3. 重启服务 =========="
pkill -f "uvicorn main:app" 2>/dev/null || true
sleep 3
nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4 >> ~/gemini-audio-service.log 2>&1 &
sleep 6
curl -s http://127.0.0.1:8000/health && echo "" && echo "✅ 服务已启动" || echo "⚠️ 健康检查失败"
