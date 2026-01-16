#!/bin/bash

# 使用sed直接在服务器上修复代码

echo "========== 在服务器上直接修复代码 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

# 备份
cp main.py main.py.backup.$(date +%Y%m%d_%H%M%S)

echo "=== 方法1: 使用sed删除文件大小检查代码块 ==="
# 删除第1012-1039行（文件大小检查代码块）
sed -i '1012,1039d' main.py

echo "=== 方法2: 删除analyze_audio_async中的文件大小检查 ==="
# 删除包含 "if file_size < 1000" 的行及其下一行（raise语句）
sed -i '/if file_size < 1000/,+1d' main.py

echo ""
echo "=== 验证修复 ==="
echo "检查 file_size < 1000:"
grep -n "file_size < 1000" main.py || echo "✅ 已移除"

echo ""
echo "检查 音频文件太小:"
grep -n "音频文件太小" main.py || echo "✅ 已移除"

echo ""
echo "=== 检查语法 ==="
source venv/bin/activate
python3 -m py_compile main.py 2>&1 | head -5

if [ $? -eq 0 ]; then
    echo "✅ 语法检查通过"
else
    echo "❌ 语法检查失败，恢复备份"
    cp main.py.backup.* main.py 2>/dev/null || echo "无法恢复备份"
fi
EOF
