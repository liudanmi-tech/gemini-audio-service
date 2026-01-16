#!/bin/bash

echo "========== 上传 .env 文件到服务器 =========="

# 检查 .env 文件是否存在
if [ ! -f .env ]; then
    echo "❌ .env 文件不存在，请先运行 ./创建env配置文件.sh"
    exit 1
fi

# 检查 GEMINI_API_KEY 是否已更新
if grep -q "your_gemini_api_key_here" .env; then
    echo "⚠️  警告: GEMINI_API_KEY 还是默认值，请先更新为实际值"
    echo "   编辑 .env 文件，将 your_gemini_api_key_here 替换为你的实际 API Key"
    read -p "是否继续上传？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 上传 .env 文件
echo "正在上传 .env 文件..."
scp .env admin@47.79.254.213:~/gemini-audio-service/.env

if [ $? -eq 0 ]; then
    echo "✅ .env 文件上传成功！"
    echo ""
    echo "========== 下一步操作 =========="
    echo "1. SSH 登录服务器:"
    echo "   ssh admin@47.79.254.213"
    echo ""
    echo "2. 安装 OSS 依赖:"
    echo "   cd ~/gemini-audio-service"
    echo "   source venv/bin/activate"
    echo "   pip3 install oss2>=2.18.0"
    echo ""
    echo "3. 重启服务:"
    echo "   pkill -f 'python.*main.py'"
    echo "   nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
    echo ""
    echo "4. 验证服务:"
    echo "   curl http://localhost:8001/health"
    echo ""
    echo "========== 一键执行脚本（在服务器上） =========="
    echo "或者运行以下命令一键完成："
    echo ""
    echo "ssh admin@47.79.254.213 'cd ~/gemini-audio-service && source venv/bin/activate && pip3 install -q oss2>=2.18.0 && pkill -f \"python.*main.py\" && sleep 2 && nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &'"
else
    echo "❌ 上传失败，请检查网络连接和服务器地址"
    exit 1
fi
