#!/bin/bash

# 上传图片空响应修复到服务器

echo "📤 开始上传图片空响应修复..."

# 上传api/profiles.py
echo "📤 上传 api/profiles.py..."
scp api/profiles.py admin@47.79.254.213:~/gemini-audio-service/api/

echo "✅ 文件上传完成！"
echo ""
echo "🔄 请在服务器上执行以下命令重启服务："
echo "   ssh admin@47.79.254.213"
echo "   cd ~/gemini-audio-service"
echo "   pkill -f 'python3 main.py'"
echo "   nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
echo "   tail -f ~/gemini-audio-service.log"
echo ""
echo "📋 部署后，请测试图片上传，并查看服务端日志："
echo "   - 应该看到'开始上传图片到OSS'"
echo "   - 应该看到'返回响应数据'"
echo "   - 如果失败，应该看到详细的错误信息"
