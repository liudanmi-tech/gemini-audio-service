#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
在阿里云控制台"命令助手"中执行此脚本，修复服务器上的 main.py
直接复制整个脚本内容到命令助手执行
"""

import os
import shutil
import re

# 切换到项目目录
project_dir = os.path.expanduser('~/gemini-audio-service')
os.chdir(project_dir)

print(f"当前目录: {os.getcwd()}")

# 备份原文件
import time
backup_file = f'main.py.backup_{int(time.time())}'
shutil.copy('main.py', backup_file)
print(f"✅ 已备份原文件到: {backup_file}")

# 读取原文件
with open('main.py', 'r', encoding='utf-8') as f:
    content = f.read()

changes_made = []

# 修复 1: 确保导入了 Query
if 'from fastapi import FastAPI, UploadFile, File, HTTPException, Query' not in content:
    content = content.replace(
        'from fastapi import FastAPI, UploadFile, File, HTTPException',
        'from fastapi import FastAPI, UploadFile, File, HTTPException, Query'
    )
    changes_made.append("添加 Query 导入")

# 修复 2: 确保 file_filename 不为 None
if 'file_filename = file.filename or "audio.m4a"' not in content:
    content = content.replace(
        'file_filename = file.filename',
        'file_filename = file.filename or "audio.m4a"'
    )
    changes_made.append("修复 file_filename 可能为 None")

# 修复 3: 在 analyze_audio_async 调用前添加日志
if 'logger.info(f"创建异步分析任务:' not in content:
    # 查找 asyncio.create_task(analyze_audio_async 这一行
    pattern = r'(asyncio\.create_task\(analyze_audio_async\(session_id, temp_file_path, file_filename, task_data\)\))'
    replacement = r'logger.info(f"创建异步分析任务: session_id={session_id}, file_path={temp_file_path}, filename={file_filename}")\n        \1'
    content = re.sub(pattern, replacement, content)
    changes_made.append("添加异步任务创建日志")

# 修复 4: 在 analyze_audio_async 函数中添加参数验证
if 'logger.info(f"========== 开始异步分析音频 ==========")' not in content:
    # 查找函数定义后的 try 块
    pattern = r'(async def analyze_audio_async\(session_id: str, temp_file_path: str, file_filename: str, task_data: dict\):.*?try:)'
    
    def add_validation(match):
        func_def = match.group(1)
        # 在 try: 后添加验证代码
        validation_code = '''try:
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
        
        '''
        return func_def.replace('try:', validation_code)
    
    content = re.sub(pattern, add_validation, content, flags=re.DOTALL)
    changes_made.append("添加参数验证和日志")

# 修复 5: 确保 analyze_audio_from_path 调用时使用 file_filename or "audio.m4a"
content = content.replace(
    'await analyze_audio_from_path(temp_file_path, file_filename)',
    'await analyze_audio_from_path(temp_file_path, file_filename or "audio.m4a")'
)
if 'await analyze_audio_from_path(temp_file_path, file_filename or "audio.m4a")' in content:
    changes_made.append("修复 analyze_audio_from_path 调用")

# 写入修复后的文件
with open('main.py', 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\n✅ 修复完成！共进行了 {len(changes_made)} 处修改:")
for change in changes_made:
    print(f"  - {change}")

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

print(f"\n✅ 所有修复完成！备份文件: {backup_file}")
print("\n下一步：重启服务")
print("执行: pkill -f 'python3 main.py' && sleep 2 && cd ~/gemini-audio-service && nohup python3 main.py > /tmp/gemini-service.log 2>&1 &")

