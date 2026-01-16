#!/bin/bash

# 检查服务器上的代码版本

echo "========== 检查代码版本 =========="
echo ""

cd ~/gemini-audio-service

echo "=== 1. 检查是否有文件大小检查 ==="
if grep -q "file_size < 1000" main.py; then
    echo "✅ 代码已包含文件大小检查"
    grep -B 2 -A 5 "file_size < 1000" main.py | head -10
else
    echo "❌ 代码未包含文件大小检查，需要更新"
fi

echo ""
echo "=== 2. 检查analyze_audio_async函数签名 ==="
grep "async def analyze_audio_async" main.py

echo ""
echo "=== 3. 检查是否创建新的数据库会话 ==="
if grep -A 10 "async def analyze_audio_async" main.py | grep -q "AsyncSessionLocal"; then
    echo "✅ 代码已更新，会创建新的数据库会话"
else
    echo "❌ 代码未更新，仍使用旧的数据库会话"
fi

echo ""
echo "=== 4. 检查失败状态更新逻辑 ==="
if grep -A 20 "except Exception as e:" main.py | grep -q "db_session.status = \"failed\""; then
    echo "✅ 代码已包含失败状态更新逻辑"
else
    echo "⚠️  代码可能未包含失败状态更新逻辑"
fi
