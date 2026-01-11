#!/bin/bash

# 在阿里云控制台的"命令助手"中执行此脚本
# 或者通过 SSH 连接后执行

cd ~/gemini-audio-service

# 备份原文件
cp main.py main.py.backup

# 使用 Python 修复文件
python3 << 'PYEOF'
import re

# 读取文件
with open('main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 检查是否需要修复
needs_fix = False

# 1. 检查是否已导入 BytesIO
if 'from io import BytesIO' not in content:
    # 在导入部分添加 BytesIO
    if 'from typing import' in content:
        content = re.sub(
            r'(from typing import List, Optional, Any)',
            r'from io import BytesIO\n\1',
            content
        )
    else:
        content = re.sub(
            r'(from datetime import datetime)',
            r'from io import BytesIO\n\1',
            content
        )
    needs_fix = True
    print("✅ 已添加 BytesIO 导入")

# 2. 修复 upload_audio_api 函数
old_pattern = r'(\s+tasks_storage\[session_id\] = task_data\s+)\n(\s+# 异步分析\s+)\n(\s+asyncio\.create_task\(analyze_audio_async\(session_id, file, task_data\)\))'

if re.search(old_pattern, content):
    new_code = '''        tasks_storage[session_id] = task_data
        
        # 读取文件内容（必须在异步任务之前读取，因为 UploadFile 只能读取一次）
        file_content = await file.read()
        file_filename = file.filename
        
        # 创建新的 UploadFile 对象用于异步分析
        new_file = UploadFile(
            filename=file_filename,
            file=BytesIO(file_content)
        )
        
        # 异步分析
        asyncio.create_task(analyze_audio_async(session_id, new_file, task_data))'''
    
    content = re.sub(old_pattern, new_code, content)
    needs_fix = True
    print("✅ 已修复 upload_audio_api 函数")

# 写入文件
if needs_fix:
    with open('main.py', 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ 文件修复完成")
else:
    print("ℹ️  文件可能已经修复过了，无需修改")

# 检查语法
import py_compile
try:
    py_compile.compile('main.py', doraise=True)
    print("✅ 语法检查通过")
except py_compile.PyCompileError as e:
    print(f"❌ 语法错误: {e}")
PYEOF

# 如果修复成功，重启服务
if [ $? -eq 0 ]; then
    echo ""
    echo "🔄 重启服务..."
    source venv/bin/activate
    pkill -f "python3 main.py"
    sleep 2
    nohup python3 main.py > /tmp/gemini-service.log 2>&1 &
    sleep 3
    
    echo ""
    echo "🧪 测试服务..."
    curl http://localhost:8001/health
    
    echo ""
    echo "✅ 完成！"
else
    echo "❌ 修复失败，请检查错误信息"
fi

