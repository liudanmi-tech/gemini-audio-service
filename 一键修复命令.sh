#!/bin/bash
# 在阿里云控制台"命令助手"中，直接复制下面的整段代码执行

cd ~/gemini-audio-service && python3 << 'EOF'
import shutil, time, re

# 备份
backup = f'main.py.backup_{int(time.time())}'
shutil.copy('main.py', backup)
print(f"✅ 备份: {backup}\n")

# 读取
with open('main.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
i = 0
fixed = []

while i < len(lines):
    line = lines[i]
    
    # 修复1: 添加 Query 导入
    if 'from fastapi import' in line and 'Query' not in line:
        line = line.replace('HTTPException', 'HTTPException, Query')
        fixed.append("添加Query导入")
    
    # 修复2: file_filename
    if 'file_filename = file.filename' in line and 'or "audio.m4a"' not in line:
        line = line.replace('file.filename', 'file.filename or "audio.m4a"')
        fixed.append("修复file_filename")
    
    # 修复3: 函数定义 - 添加 task_data
    if 'async def analyze_audio_async(' in line:
        if 'task_data' not in line:
            # 检查是哪种格式
            if line.strip().endswith('file_filename: str):'):
                line = line.replace('file_filename: str):', 'file_filename: str, task_data: dict):')
                fixed.append("函数定义添加task_data")
            elif 'file_filename: str,' in line and 'task_data' not in line:
                line = line.replace('file_filename: str,', 'file_filename: str, task_data: dict,')
                fixed.append("函数定义添加task_data")
    
    # 修复4: 函数调用 - 添加 task_data
    if 'asyncio.create_task(analyze_audio_async(' in line:
        if 'task_data' not in line:
            if 'file_filename))' in line:
                line = line.replace('file_filename))', 'file_filename, task_data))')
                fixed.append("函数调用添加task_data")
            elif 'file_filename)' in line and 'task_data' not in line:
                line = line.replace('file_filename)', 'file_filename, task_data)')
                fixed.append("函数调用添加task_data")
    
    new_lines.append(line)
    i += 1

# 写入
with open('main.py', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"✅ 修复完成，共 {len(fixed)} 处:")
for f in fixed:
    print(f"  - {f}")

# 检查语法
import py_compile
try:
    py_compile.compile('main.py', doraise=True)
    print("\n✅ 语法检查通过")
except Exception as e:
    print(f"\n❌ 语法错误: {e}")
    shutil.copy(backup, 'main.py')
    raise

print(f"\n✅ 修复成功！备份: {backup}")
EOF

# 重启服务
cd ~/gemini-audio-service && pkill -f "python3 main.py" 2>/dev/null; sleep 2 && nohup python3 main.py > /tmp/gemini-service.log 2>&1 & sleep 3 && echo "✅ 服务已重启" && curl -s http://localhost:8001/health

