#!/bin/bash

# 验证服务器上的代码是否已更新

echo "========== 验证服务器代码更新 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

echo "=== 1. 检查是否还有文件大小检查的错误消息 ==="
if grep -q "音频文件太小，无法分析" main.py; then
    echo "❌ 代码中仍然包含文件大小检查"
    echo "找到的行："
    grep -n "音频文件太小，无法分析" main.py
else
    echo "✅ 代码中已移除文件大小检查的错误消息"
fi

echo ""
echo "=== 2. 检查是否还有 file_size < 1000 检查 ==="
if grep -q "file_size < 1000" main.py; then
    echo "❌ 代码中仍然包含 file_size < 1000 检查"
    echo "找到的行："
    grep -n "file_size < 1000" main.py
else
    echo "✅ 代码中已移除 file_size < 1000 检查"
fi

echo ""
echo "=== 3. 查看上传接口的关键代码（第1008-1045行）==="
sed -n '1008,1045p' main.py

echo ""
echo "=== 4. 验证服务是否正常启动 ==="
tail -20 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|ERROR|错误" | tail -5
EOF
