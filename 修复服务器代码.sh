#!/bin/bash
# 在阿里云控制台"命令助手"中执行此脚本，修复服务器上的 main.py

cat > /tmp/fix_main.py << 'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复服务器上的 main.py 文件
在阿里云控制台"命令助手"中执行此脚本
"""

import os
import shutil
from pathlib import Path

# 切换到项目目录
project_dir = os.path.expanduser('~/gemini-audio-service')
os.chdir(project_dir)

print(f"当前目录: {os.getcwd()}")

# 备份原文件
backup_file = 'main.py.backup_' + str(int(__import__('time').time()))
shutil.copy('main.py', backup_file)
print(f"✅ 已备份原文件到: {backup_file}")

# 读取原文件
with open('main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复 1: 确保导入了 Query
if 'from fastapi import FastAPI, UploadFile, File, HTTPException, Query' not in content:
    # 替换导入语句
    content = content.replace(
        'from fastapi import FastAPI, UploadFile, File, HTTPException',
        'from fastapi import FastAPI, UploadFile, File, HTTPException, Query'
    )
    print("✅ 已添加 Query 导入")

# 修复 2: 确保 file_filename 不为 None
old_code_1 = """        file_content = await file.read()
        file_filename = file.filename
        file_ext = Path(file_filename).suffix.lower() if file_filename else '.m4a'"""
new_code_1 = """        file_content = await file.read()
        file_filename = file.filename or "audio.m4a"
        file_ext = Path(file_filename).suffix.lower() if file_filename else '.m4a'"""

if old_code_1 in content:
    content = content.replace(old_code_1, new_code_1)
    print("✅ 已修复 file_filename 可能为 None 的问题")

# 修复 3: 确保 analyze_audio_async 调用时传递了所有参数
old_code_2 = """        # 异步分析（传递临时文件路径和文件名）
        asyncio.create_task(analyze_audio_async(session_id, temp_file_path, file_filename, task_data))"""
new_code_2 = """        # 异步分析（传递临时文件路径和文件名，确保所有参数都正确传递）
        logger.info(f"创建异步分析任务: session_id={session_id}, file_path={temp_file_path}, filename={file_filename}")
        asyncio.create_task(analyze_audio_async(session_id, temp_file_path, file_filename, task_data))"""

if old_code_2 in content and 'logger.info(f"创建异步分析任务' not in content:
    content = content.replace(old_code_2, new_code_2)
    print("✅ 已添加日志记录")

# 修复 4: 确保 analyze_audio_async 函数有参数验证
old_code_3 = """async def analyze_audio_async(session_id: str, temp_file_path: str, file_filename: str, task_data: dict):
    \"\"\"异步分析音频文件\"\"\"
    from datetime import datetime
    
    try:
        # 直接使用临时文件路径调用 analyze_audio_from_path
        result = await analyze_audio_from_path(temp_file_path, file_filename)"""
new_code_3 = """async def analyze_audio_async(session_id: str, temp_file_path: str, file_filename: str, task_data: dict):
    \"\"\"异步分析音频文件\"\"\"
    from datetime import datetime
    
    try:
        logger.info(f"========== 开始异步分析音频 ==========")
        logger.info(f"session_id: {session_id}")
        logger.info(f"temp_file_path: {temp_file_path}")
        logger.info(f"file_filename: {file_filename}")
        logger.info(f"task_data keys: {list(task_data.keys()) if task_data else 'None'}")
        
        # 验证参数
        if not task_data:
            raise ValueError("task_data 参数不能为空")
        if not session_id:
            raise ValueError("session_id 参数不能为空")
        if not temp_file_path:
            raise ValueError("temp_file_path 参数不能为空")
        
        # 直接使用临时文件路径调用 analyze_audio_from_path
        result = await analyze_audio_from_path(temp_file_path, file_filename or "audio.m4a")"""

if 'logger.info(f"========== 开始异步分析音频 ==========")' not in content:
    # 查找 analyze_audio_async 函数定义
    import re
    pattern = r'(async def analyze_audio_async\(session_id: str, temp_file_path: str, file_filename: str, task_data: dict\):.*?try:\s+# 直接使用临时文件路径调用 analyze_audio_from_path\s+result = await analyze_audio_from_path\(temp_file_path, file_filename\))'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        old_func_start = match.group(1)
        new_func_start = old_func_start.replace(
            'try:\n        # 直接使用临时文件路径调用 analyze_audio_from_path\n        result = await analyze_audio_from_path(temp_file_path, file_filename)',
            '''try:
        logger.info(f"========== 开始异步分析音频 ==========")
        logger.info(f"session_id: {session_id}")
        logger.info(f"temp_file_path: {temp_file_path}")
        logger.info(f"file_filename: {file_filename}")
        logger.info(f"task_data keys: {list(task_data.keys()) if task_data else 'None'}")
        
        # 验证参数
        if not task_data:
            raise ValueError("task_data 参数不能为空")
        if not session_id:
            raise ValueError("session_id 参数不能为空")
        if not temp_file_path:
            raise ValueError("temp_file_path 参数不能为空")
        
        # 直接使用临时文件路径调用 analyze_audio_from_path
        result = await analyze_audio_from_path(temp_file_path, file_filename or "audio.m4a")'''
        )
        content = content.replace(old_func_start, new_func_start)
        print("✅ 已添加参数验证和日志记录")
    else:
        # 如果正则匹配失败，尝试简单替换
        if 'logger.info(f"========== 开始异步分析音频 ==========")' not in content:
            # 查找 analyze_audio_async 函数中的 try 块
            lines = content.split('\n')
            new_lines = []
            in_analyze_func = False
            found_try = False
            for i, line in enumerate(lines):
                if 'async def analyze_audio_async' in line:
                    in_analyze_func = True
                    new_lines.append(line)
                elif in_analyze_func and 'try:' in line and not found_try:
                    found_try = True
                    new_lines.append(line)
                    # 添加日志和验证
                    new_lines.append('        logger.info(f"========== 开始异步分析音频 ==========")')
                    new_lines.append('        logger.info(f"session_id: {session_id}")')
                    new_lines.append('        logger.info(f"temp_file_path: {temp_file_path}")')
                    new_lines.append('        logger.info(f"file_filename: {file_filename}")')
                    new_lines.append('        logger.info(f"task_data keys: {list(task_data.keys()) if task_data else \'None\'}")')
                    new_lines.append('')
                    new_lines.append('        # 验证参数')
                    new_lines.append('        if not task_data:')
                    new_lines.append('            raise ValueError("task_data 参数不能为空")')
                    new_lines.append('        if not session_id:')
                    new_lines.append('            raise ValueError("session_id 参数不能为空")')
                    new_lines.append('        if not temp_file_path:')
                    new_lines.append('            raise ValueError("temp_file_path 参数不能为空")')
                    new_lines.append('')
                elif in_analyze_func and 'result = await analyze_audio_from_path(temp_file_path, file_filename)' in line:
                    # 确保使用 file_filename or "audio.m4a"
                    new_lines.append(line.replace('file_filename)', 'file_filename or "audio.m4a")'))
                else:
                    new_lines.append(line)
            content = '\n'.join(new_lines)
            print("✅ 已添加参数验证和日志记录（使用行替换方法）")

# 写入修复后的文件
with open('main.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件修复完成")

# 检查语法
print("\n检查语法...")
try:
    import py_compile
    py_compile.compile('main.py', doraise=True)
    print("✅ 语法检查通过")
except py_compile.PyCompileError as e:
    print(f"❌ 语法错误: {e}")
    print("正在恢复备份...")
    shutil.copy(backup_file, 'main.py')
    raise

print(f"\n✅ 修复完成！备份文件: {backup_file}")
PYEOF

# 在服务器上执行修复脚本
python3 /tmp/fix_main.py

