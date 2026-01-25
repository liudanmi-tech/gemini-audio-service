#!/bin/bash

# 上传OSS图片权限修复到服务器

echo "📤 开始上传OSS图片权限修复..."

# 上传main.py
echo "📤 上传 main.py..."
scp main.py admin@47.79.254.213:~/gemini-audio-service/

echo "✅ 文件上传完成！"
echo ""
echo "🔄 请在服务器上执行以下命令重启服务："
echo "   ssh admin@47.79.254.213"
echo "   cd ~/gemini-audio-service"
echo "   pkill -f 'python3 main.py'"
echo "   nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
echo "   tail -f ~/gemini-audio-service.log"
