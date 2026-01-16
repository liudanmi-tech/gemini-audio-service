#!/bin/bash

# 上传更新后的代码和测试脚本到服务器

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 上传更新后的代码 =========="
echo ""

echo "1. 上传 main.py..."
scp main.py ${SERVER}:${REMOTE_DIR}/

echo ""
echo "2. 上传测试脚本..."
scp 测试图片生成配额.sh ${SERVER}:${REMOTE_DIR}/
scp 诊断图片生成配额问题.md ${SERVER}:${REMOTE_DIR}/

echo ""
echo "✅ 文件上传完成！"
echo ""
echo "========== 在服务器上执行以下命令 =========="
echo ""
echo "cd ~/gemini-audio-service"
echo "source venv/bin/activate"
echo "chmod +x 测试图片生成配额.sh"
echo "./测试图片生成配额.sh"
echo ""
echo "或者执行完整测试和重启服务："
echo ""
echo "cd ~/gemini-audio-service"
echo "source venv/bin/activate"
echo "chmod +x 测试图片生成配额.sh"
echo "./测试图片生成配额.sh"
echo ""
echo "# 如果测试通过，重启服务"
echo "pkill -f 'python.*main.py'"
echo "sleep 2"
echo "nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
echo "sleep 3"
echo "ps aux | grep '[p]ython.*main.py'"
echo ""
