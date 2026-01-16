#!/bin/bash

# 直接在服务器上修复代码

echo "========== 直接在服务器上修复代码 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

# 备份
cp main.py main.py.backup.$(date +%Y%m%d_%H%M%S)

echo "=== 修复第1处：上传接口的文件大小检查 ==="
# 删除第1012-1039行的文件大小检查代码块
# 使用Python脚本来精确删除
python3 << 'PYTHON'
import re

with open('main.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 找到要删除的行范围
# 第1012行开始是注释 "# 检查文件大小（如果太小可能无法分析）"
# 到第1039行结束是 "            )"
start_line = None
end_line = None
in_block = False
indent_level = None

for i, line in enumerate(lines):
    line_num = i + 1
    # 找到开始行
    if line_num == 1012 and "# 检查文件大小" in line:
        start_line = i
        in_block = True
        indent_level = len(line) - len(line.lstrip())
    # 找到结束行（return JSONResponse 之后）
    elif in_block and line_num > 1012:
        # 检查是否是 return JSONResponse 块的结束
        if 'return JSONResponse' in line:
            # 找到对应的闭合括号
            pass
        # 如果缩进回到原来的级别，说明块结束了
        if line.strip() and not line.strip().startswith('#'):
            current_indent = len(line) - len(line.lstrip())
            if current_indent <= indent_level and 'return JSONResponse' not in lines[i-1] if i > 0 else False:
                # 检查前一行是否是 return JSONResponse 的结束
                if i > 0 and ')' in lines[i-1] and 'JSONResponse' in lines[i-1]:
                    end_line = i - 1
                    break

# 更简单的方法：直接删除1012-1039行
if start_line is None:
    # 手动查找
    for i, line in enumerate(lines):
        if i >= 1011 and "# 检查文件大小" in line:
            start_line = i
            break

if start_line is not None:
    # 找到结束行（包含 return JSONResponse 的整个块）
    for i in range(start_line, min(start_line + 30, len(lines))):
        if i > start_line and 'return JSONResponse' in lines[i]:
            # 找到这个块的结束（下一个非空行且缩进减少）
            for j in range(i, min(i + 10, len(lines))):
                if lines[j].strip() and not lines[j].strip().startswith('#'):
                    current_indent = len(lines[j]) - len(lines[j].lstrip())
                    if current_indent < len(lines[start_line]) - len(lines[start_line].lstrip()):
                        end_line = j
                        break
                if end_line:
                    break
            break

# 删除行
if start_line is not None and end_line is not None:
    print(f"删除第 {start_line + 1} 到 {end_line + 1} 行")
    del lines[start_line:end_line]
else:
    print("未找到要删除的代码块")

# 修复第2处：analyze_audio_async 函数中的文件大小检查
# 找到第1113-1118行
for i, line in enumerate(lines):
    line_num = i + 1
    if line_num == 1113 and "# 检查文件大小" in line:
        # 删除到第1118行（包含 if file_size < 1000 的整个块）
        # 但保留文件大小日志记录
        # 找到 if file_size < 1000 的行
        for j in range(i, min(i + 10, len(lines))):
            if 'if file_size < 1000' in lines[j]:
                # 删除从注释到 if 语句结束的行
                # 但保留文件大小日志
                # 实际上只需要删除 if 语句
                del lines[j:j+2]  # 删除 if 和 raise 两行
                break
        break

with open('main.py', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("修复完成")
PYTHON

echo ""
echo "=== 验证修复 ==="
grep -n "file_size < 1000" main.py || echo "✅ 文件大小检查已移除"
grep -n "音频文件太小" main.py || echo "✅ 错误消息已移除"

echo ""
echo "=== 检查语法 ==="
source venv/bin/activate
python3 -m py_compile main.py 2>&1 | head -10
EOF
