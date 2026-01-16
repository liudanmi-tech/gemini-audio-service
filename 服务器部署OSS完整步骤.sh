#!/bin/bash

# 服务器端一键部署脚本
# 在服务器上执行此脚本，完成 OSS 配置和依赖安装

echo "========== 服务器端 OSS 部署脚本 =========="

cd ~/gemini-audio-service || exit 1

# 1. 激活虚拟环境
echo "1. 激活虚拟环境..."
source venv/bin/activate || exit 1

# 2. 检查 .env 文件
echo "2. 检查 .env 文件..."
if [ ! -f .env ]; then
    echo "❌ .env 文件不存在，请先上传"
    exit 1
fi

# 3. 安装 OSS 依赖
echo "3. 安装 OSS 依赖 (oss2)..."
pip3 install -q oss2>=2.18.0
if [ $? -eq 0 ]; then
    echo "✅ oss2 安装成功"
else
    echo "❌ oss2 安装失败"
    exit 1
fi

# 4. 验证 OSS 配置
echo "4. 验证 OSS 配置..."
python3 -c "
import os
from dotenv import load_dotenv
load_dotenv()
print('OSS 配置检查:')
print('  OSS_ACCESS_KEY_ID:', os.getenv('OSS_ACCESS_KEY_ID')[:10] + '...' if os.getenv('OSS_ACCESS_KEY_ID') else '❌ 未设置')
print('  OSS_ENDPOINT:', os.getenv('OSS_ENDPOINT') or '❌ 未设置')
print('  OSS_BUCKET_NAME:', os.getenv('OSS_BUCKET_NAME') or '❌ 未设置')
print('  USE_OSS:', os.getenv('USE_OSS', 'true'))
"

# 5. 停止旧服务
echo "5. 停止旧服务..."
pkill -f 'python.*main.py'
sleep 2

# 6. 启动新服务
echo "6. 启动新服务..."
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 3

# 7. 检查服务状态
echo "7. 检查服务状态..."
if ps aux | grep -q '[p]ython.*main.py'; then
    echo "✅ 服务已启动"
    echo ""
    echo "8. 验证服务..."
    curl -s http://localhost:8001/health | python3 -m json.tool || echo "⚠️  服务可能还在启动中，请稍后检查"
    echo ""
    echo "========== 部署完成 =========="
    echo "查看日志: tail -f ~/gemini-audio-service.log"
else
    echo "❌ 服务启动失败，查看日志:"
    tail -30 ~/gemini-audio-service.log
    exit 1
fi
