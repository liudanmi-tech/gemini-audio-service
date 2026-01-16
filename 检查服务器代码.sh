#!/bin/bash

# 检查服务器上的代码是否已更新

echo "========== 检查服务器上的代码 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

echo "=== 1. 检查是否还有文件大小检查 ==="
if grep -q "音频文件太小，无法分析" main.py; then
    echo "❌ 代码中仍然包含文件大小检查"
    grep -n "音频文件太小，无法分析" main.py
else
    echo "✅ 代码中已移除文件大小检查"
fi

echo ""
echo "=== 2. 检查文件大小检查代码 ==="
if grep -q "file_size < 1000" main.py; then
    echo "❌ 代码中仍然包含 file_size < 1000 检查"
    grep -n "file_size < 1000" main.py
else
    echo "✅ 代码中已移除 file_size < 1000 检查"
fi

echo ""
echo "=== 3. 查看上传接口的相关代码（第1000-1050行）==="
sed -n '1000,1050p' main.py | head -30
EOF
