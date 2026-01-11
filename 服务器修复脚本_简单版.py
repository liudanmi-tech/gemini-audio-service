#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
在阿里云控制台"命令助手"中执行此脚本
直接复制整个脚本内容执行
"""

import os
import shutil
import time

os.chdir(os.path.expanduser('~/gemini-audio-service'))

# 备份
backup = f'main.py.backup_{int(time.time())}'
shutil.copy('main.py', backup)
print(f"✅ 备份: {backup}")

# 读取
with open('main.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
i = 0
changes = []

while i < len(lines):
    line = lines[i]
    
    # 修复 1: 添加 Query 导入
    if 'from fastapi import FastAPI, UploadFile, File, HTTPException' in line and 'Query' not in line:
        line = line.replace('HTTPException', 'HTTPException, Query')
        changes.append("添加 Query 导入")
    
    # 修复 2: 修复 file_filename
    if 'file_filename = file.filename' in line and 'or "audio.m4a"' not in line:
        line = line.replace('file_filename = file.filename', 'file_filename = file.filename or "audio.m4a"')
        changes.append("修复 file_filename")
    
    # 修复 3: 在 asyncio.create_task 前添加日志
    if 'asyncio.create_task(analyze_audio_async(session_id, temp_file_path, file_filename, task_data))' in line:
        indent = len(line) - len(line.lstrip())
        new_lines.append(' ' * indent + 'logger.info(f"创建异步分析任务: session_id={session_id}, file_path={temp_file_path}, filename={file_filename}")\n')
        changes.append("添加日志")
    
    # 修复 4: 在 analyze_audio_async 函数中添加验证
    if 'async def analyze_audio_async(session_id: str, temp_file_path: str, file_filename: str, task_data: dict):' in line:
        new_lines.append(line)
        i += 1
        # 跳过文档字符串和 from datetime import
        while i < len(lines) and ('"""' in lines[i] or 'from datetime import' in lines[i] or lines[i].strip() == ''):
            new_lines.append(lines[i])
            i += 1
        # 找到 try: 行
        if i < len(lines) and 'try:' in lines[i]:
            new_lines.append(lines[i])  # try:
            i += 1
            # 添加验证代码
            indent = len(lines[i-1]) - len(lines[i-1].lstrip())
            new_lines.append(' ' * indent + 'logger.info(f"========== 开始异步分析音频 ==========")\n')
            new_lines.append(' ' * indent + 'logger.info(f"session_id: {session_id}")\n')
            new_lines.append(' ' * indent + 'logger.info(f"temp_file_path: {temp_file_path}")\n')
            new_lines.append(' ' * indent + 'logger.info(f"file_filename: {file_filename}")\n')
            new_lines.append(' ' * indent + 'logger.info(f"task_data keys: {list(task_data.keys()) if task_data else \'None\'}")\n')
            new_lines.append(' ' * indent + '\n')
            new_lines.append(' ' * indent + '# 验证参数\n')
            new_lines.append(' ' * indent + 'if not task_data:\n')
            new_lines.append(' ' * (indent + 4) + 'raise ValueError("task_data 参数不能为空")\n')
            new_lines.append(' ' * indent + 'if not session_id:\n')
            new_lines.append(' ' * (indent + 4) + 'raise ValueError("session_id 参数不能为空")\n')
            new_lines.append(' ' * indent + 'if not temp_file_path:\n')
            new_lines.append(' ' * (indent + 4) + 'raise ValueError("temp_file_path 参数不能为空")\n')
            new_lines.append(' ' * indent + '\n')
            changes.append("添加参数验证")
            continue
    
    # 修复 5: 修复 analyze_audio_from_path 调用
    if 'await analyze_audio_from_path(temp_file_path, file_filename)' in line and 'or "audio.m4a"' not in line:
        line = line.replace('file_filename)', 'file_filename or "audio.m4a")')
        changes.append("修复函数调用")
    
    new_lines.append(line)
    i += 1

# 写入
with open('main.py', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"✅ 修复完成，共 {len(changes)} 处修改:")
for c in changes:
    print(f"  - {c}")

# 检查语法
import py_compile
try:
    py_compile.compile('main.py', doraise=True)
    print("✅ 语法检查通过")
except Exception as e:
    print(f"❌ 语法错误: {e}")
    shutil.copy(backup, 'main.py')
    raise

print(f"\n✅ 修复成功！备份: {backup}")

