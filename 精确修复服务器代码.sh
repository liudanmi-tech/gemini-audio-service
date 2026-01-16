#!/bin/bash

# 精确修复服务器上的缩进问题

echo "========== 在服务器上精确修复缩进 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

# 恢复备份（如果有）
if [ -f main.py.backup ]; then
    echo "恢复备份..."
    cp main.py.backup main.py
fi

# 查看当前第1190行的缩进
echo "修复前第1190行："
sed -n "1190p" main.py | cat -A

# 精确修复：只修复1123-1189行，将8个空格改为12个空格
# 但需要先检查这些行的实际缩进
echo ""
echo "检查1123-1190行的缩进："
sed -n "1123,1190p" main.py | cat -A | head -10

# 修复：只修复1123-1189行（不包括1190行）
# 使用Python脚本来精确修复
python3 << 'PYTHON'
import re

with open('main.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复1123-1189行（索引从0开始，所以是1122-1188）
for i in range(1122, 1189):  # 1123-1189行（0-based: 1122-1188）
    if i < len(lines):
        line = lines[i]
        # 如果行以8个空格开头（不在try块内），改为12个空格
        if line.startswith('        ') and not line.startswith('            '):
            lines[i] = '            ' + line[8:]
            print(f"修复第{i+1}行")

with open('main.py', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("修复完成")
PYTHON

# 验证修复
source venv/bin/activate
python3 -m py_compile main.py 2>&1

if [ $? -eq 0 ]; then
    echo "✅ 语法检查通过"
    echo ""
    echo "修复后的第1123-1130行："
    sed -n "1123,1130p" main.py
    echo ""
    echo "修复后的第1188-1192行："
    sed -n "1188,1192p" main.py
else
    echo "❌ 语法检查失败"
    echo "查看错误："
    python3 -m py_compile main.py 2>&1
fi
EOF
