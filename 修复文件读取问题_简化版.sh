#!/bin/bash
# 修复文件读取问题 - 简化版（分步执行）

cd /home/admin/gemini-audio-service
cp main.py main.py.backup4

# 方法：使用 Python 脚本修复，确保缩进正确
python3 << 'ENDPYTHON'
import re

with open('main.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 找到 upload_audio_api 函数中需要替换的部分
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # 查找 tasks_storage[session_id] = task_data 这一行
    if 'tasks_storage[session_id] = task_data' in line:
        new_lines.append(line)
        i += 1
        
        # 跳过旧代码，直到 asyncio.create_task
        while i < len(lines) and 'asyncio.create_task(analyze_audio_async(session_id' not in lines[i]:
            i += 1
        
        # 添加新代码
        new_lines.append('\n')
        new_lines.append('        # 读取文件内容并保存到临时文件（必须在异步任务之前读取，因为 UploadFile 只能读取一次）\n')
        new_lines.append('        file_content = await file.read()\n')
        new_lines.append('        file_filename = file.filename\n')
        new_lines.append("        file_ext = Path(file_filename).suffix.lower() if file_filename else '.m4a'\n")
        new_lines.append('\n')
        new_lines.append('        # 创建临时文件保存文件内容\n')
        new_lines.append('        import tempfile\n')
        new_lines.append('        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_ext)\n')
        new_lines.append('        temp_file.write(file_content)\n')
        new_lines.append('        temp_file.close()\n')
        new_lines.append('        temp_file_path = temp_file.name\n')
        new_lines.append('\n')
        new_lines.append('        # 异步分析（传递临时文件路径和文件名）\n')
        new_lines.append('        asyncio.create_task(analyze_audio_async(session_id, temp_file_path, file_filename, task_data))\n')
        
        # 跳过旧的 asyncio.create_task 行
        i += 1
        continue
    
    # 修复 analyze_audio_async 函数签名
    if 'async def analyze_audio_async(session_id: str, file: UploadFile, task_data: dict):' in line:
        new_lines.append('async def analyze_audio_async(session_id: str, temp_file_path: str, file_filename: str, task_data: dict):\n')
        i += 1
        continue
    
    # 修复 analyze_audio_async 函数体中的 try 块
    if '    try:' in line and i > 0 and 'async def analyze_audio_async' in ''.join(lines[max(0, i-5):i]):
        new_lines.append(line)
        i += 1
        
        # 如果下一行是 result = await analyze_audio(file)，替换它
        if i < len(lines) and 'result = await analyze_audio(file)' in lines[i]:
            new_lines.append('        # 从临时文件创建 UploadFile 对象\n')
            new_lines.append('        with open(temp_file_path, \'rb\') as f:\n')
            new_lines.append('            file_content = f.read()\n')
            new_lines.append('\n')
            new_lines.append('        # 创建新的 UploadFile 对象\n')
            new_lines.append('        from io import BytesIO\n')
            new_lines.append('        file_obj = BytesIO(file_content)\n')
            new_lines.append('        file_obj.seek(0)  # 确保位置在开头\n')
            new_lines.append('\n')
            new_lines.append('        # 创建 UploadFile 对象\n')
            new_lines.append('        new_file = UploadFile(\n')
            new_lines.append('            filename=file_filename,\n')
            new_lines.append('            file=file_obj\n')
            new_lines.append('        )\n')
            new_lines.append('\n')
            new_lines.append('        result = await analyze_audio(new_file)\n')
            i += 1
            continue
    
    # 修复 except 块，添加 finally
    if '    except Exception as e:' in line and i > 0:
        # 检查是否在 analyze_audio_async 函数中
        context = ''.join(lines[max(0, i-20):i])
        if 'async def analyze_audio_async' in context:
            new_lines.append(line)
            i += 1
            
            # 读取 except 块内容
            except_lines = []
            while i < len(lines) and not lines[i].strip().startswith('except') and not lines[i].strip().startswith('finally') and (lines[i].startswith(' ') or lines[i].startswith('\t') or lines[i].strip() == ''):
                except_lines.append(lines[i])
                i += 1
            
            # 添加 traceback
            new_lines.append('        logger.error(f"分析音频失败: {e}")\n')
            new_lines.append('        logger.error(traceback.format_exc())\n')
            new_lines.append('        task_data["status"] = "failed"\n')
            new_lines.append('        task_data["updated_at"] = datetime.now().isoformat()\n')
            new_lines.append('    finally:\n')
            new_lines.append('        # 清理临时文件\n')
            new_lines.append('        if temp_file_path and os.path.exists(temp_file_path):\n')
            new_lines.append('            try:\n')
            new_lines.append('                os.unlink(temp_file_path)\n')
            new_lines.append('                logger.info(f"已删除临时文件: {temp_file_path}")\n')
            new_lines.append('            except Exception as e:\n')
            new_lines.append('                logger.error(f"删除临时文件失败: {e}")\n')
            continue
    
    new_lines.append(line)
    i += 1

# 写入文件
with open('main.py', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("✅ 文件修复完成")

# 检查语法
import py_compile
try:
    py_compile.compile('main.py', doraise=True)
    print("✅ 语法检查通过")
except Exception as e:
    print(f"❌ 语法错误: {e}")
ENDPYTHON

