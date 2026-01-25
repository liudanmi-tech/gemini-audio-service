#!/bin/bash

# 上传数据库性能优化文件到服务器

echo "📤 开始上传数据库性能优化文件..."

# 上传数据库连接配置
echo "📤 上传 database/connection.py..."
scp database/connection.py admin@47.79.254.213:~/gemini-audio-service/database/

# 上传档案API
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
