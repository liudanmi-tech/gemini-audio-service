#!/bin/bash
# 快速上传项目到服务器并启动服务

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "📤 开始上传项目到服务器..."

# 使用 rsync 上传（排除不需要的文件）
rsync -avz \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  --exclude '.git' \
  --exclude 'Models.swift' \
  --exclude '*.md' \
  --exclude '.DS_Store' \
  --exclude '*.swift' \
  --exclude 'iOS_*.md' \
  --exclude '*.xcodeproj' \
  --exclude '*.xcworkspace' \
  . $SERVER:$REMOTE_DIR/

echo "✅ 上传完成！"
echo ""
echo "🔧 正在服务器上安装依赖并启动服务..."

# 在服务器上执行命令
ssh $SERVER << 'ENDSSH'
cd ~/gemini-audio-service

# 创建虚拟环境（如果不存在）
if [ ! -d "venv" ]; then
    echo "创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境并安装依赖
echo "激活虚拟环境..."
source venv/bin/activate

echo "安装依赖..."
pip3 install -r requirements.txt

# 停止旧进程（如果存在）
echo "停止旧进程..."
pkill -f "python3 main.py" 2>/dev/null
sleep 1

# 启动服务
echo "启动服务..."
nohup python3 main.py > /tmp/gemini-service.log 2>&1 &

sleep 2

# 检查进程
echo ""
echo "检查服务状态..."
ps aux | grep python3 | grep main.py | grep -v grep

# 检查端口
echo ""
echo "检查端口 8001..."
sudo netstat -tlnp | grep 8001 || echo "（需要 root 权限查看端口）"

# 测试 API
echo ""
echo "测试 API..."
curl -s http://localhost:8001/health || echo "API 测试失败"

# 显示日志
echo ""
echo "最近 20 行日志："
tail -20 /tmp/gemini-service.log
ENDSSH

echo ""
echo "✅ 完成！"
echo "📋 查看日志: ssh $SERVER 'tail -f /tmp/gemini-service.log'"

