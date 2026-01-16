#!/bin/bash

# 在服务器上直接修复缩进问题

echo "========== 1. 重新上传代码 =========="
cd ~/Desktop/AI军师/gemini-audio-service
scp main.py admin@47.79.254.213:~/gemini-audio-service/

echo ""
echo "========== 2. 在服务器上验证并修复 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

# 备份原文件
cp main.py main.py.backup.$(date +%Y%m%d_%H%M%S)

# 检查第1123行的缩进
echo "修复前的第1123行："
sed -n "1123p" main.py | cat -A

# 修复缩进：将1123-1190行的8个空格缩进改为12个空格（在try块内）
# 但需要小心，因为有些行可能已经是正确的缩进
# 更安全的方法：直接替换整个问题区域

# 先检查语法
source venv/bin/activate
python3 -m py_compile main.py 2>&1

if [ $? -ne 0 ]; then
    echo "❌ 语法检查失败，需要修复"
    echo "查看问题区域："
    sed -n "1120,1130p" main.py
else
    echo "✅ 语法检查通过"
fi
EOF

echo ""
echo "========== 3. 如果上传失败，手动修复 =========="
echo "在服务器上执行以下命令修复缩进："
echo ""
echo "cd ~/gemini-audio-service"
echo "sed -i '1123,1190s/^        /            /' main.py"
echo "source venv/bin/activate"
echo "python3 -m py_compile main.py"
