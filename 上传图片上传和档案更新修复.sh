#!/bin/bash

# 上传图片上传和档案更新修复到服务器

echo "📤 开始上传修复文件..."

# 上传档案API（修复空响应问题）
echo "📤 上传 api/profiles.py..."
scp api/profiles.py admin@47.79.254.213:~/gemini-audio-service/api/

echo "✅ 文件上传完成！"
echo ""
echo "⚠️  注意：NetworkManager.swift 需要重新编译iOS应用才能生效"
echo ""
echo "🔄 请在服务器上执行以下命令重启服务："
echo "   ssh admin@47.79.254.213"
echo "   cd ~/gemini-audio-service"
echo "   pkill -f 'python3 main.py'"
echo "   nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
echo "   tail -f ~/gemini-audio-service.log"
