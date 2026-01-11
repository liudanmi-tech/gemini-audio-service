# 修复服务器 main.py - 最简单方法

## 问题
`analyze_audio_async` 函数中尝试创建 `UploadFile` 对象，但文件流已关闭，导致 "I/O operation on closed file" 错误。

## 解决方案：只修复关键部分

在**阿里云控制台 → 命令助手**中执行以下命令：

### 步骤 1: 备份当前文件

```bash
cd /home/admin/gemini-audio-service
cp main.py main.py.backup7
```

### 步骤 2: 修复 analyze_audio_async 函数

```bash
python3 << 'ENDPYTHON'
import re

with open('main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 查找并替换 analyze_audio_async 函数中的问题代码
# 原来的代码：创建 UploadFile 对象并调用 analyze_audio
# 修复后：直接调用 analyze_audio_from_path

old_pattern = r'(\s+)# 从临时文件创建 UploadFile 对象.*?result = await analyze_audio\(new_file\)'
new_replacement = r'\1# 直接使用临时文件路径调用 analyze_audio_from_path\n\1result = await analyze_audio_from_path(temp_file_path, file_filename)'

# 使用多行模式匹配
content_new = re.sub(
    old_pattern,
    new_replacement,
    content,
    flags=re.DOTALL
)

# 如果上面的替换没有成功，尝试更精确的替换
if 'result = await analyze_audio(new_file)' in content:
    # 找到 analyze_audio_async 函数
    lines = content.split('\n')
    new_lines = []
    skip_until_result = False
    
    for i, line in enumerate(lines):
        if 'async def analyze_audio_async' in line:
            skip_until_result = True
            new_lines.append(line)
        elif skip_until_result:
            if 'result = await analyze_audio(new_file)' in line:
                # 替换这一行
                indent = len(line) - len(line.lstrip())
                new_lines.append(' ' * indent + '# 直接使用临时文件路径调用 analyze_audio_from_path')
                new_lines.append(' ' * indent + 'result = await analyze_audio_from_path(temp_file_path, file_filename)')
                skip_until_result = False
            elif 'from io import BytesIO' in line or 'file_obj = BytesIO' in line or 'new_file = UploadFile' in line:
                # 跳过这些行（删除创建 UploadFile 的代码）
                continue
            elif 'with open(temp_file_path' in line and 'file_content = f.read()' in lines[i+1] if i+1 < len(lines) else False:
                # 跳过读取文件内容的代码块
                continue
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
    
    content_new = '\n'.join(new_lines)

# 确保 analyze_audio_from_path 函数存在（如果不存在，需要添加）
if 'async def analyze_audio_from_path' not in content_new:
    print('⚠️  警告：analyze_audio_from_path 函数不存在，需要添加')
    print('   请使用完整文件替换方法')

# 写入修复后的文件
with open('main.py', 'w', encoding='utf-8') as f:
    f.write(content_new)

print('✅ 文件修复完成')

# 检查语法
import py_compile
try:
    py_compile.compile('main.py', doraise=True)
    print('✅ 语法检查通过')
except py_compile.PyCompileError as e:
    print(f'❌ 语法检查失败: {e}')
    print('   正在恢复备份...')
    import shutil
    shutil.copy('main.py.backup7', 'main.py')
    print('   已恢复备份文件')
ENDPYTHON
```

### 步骤 3: 验证修复

```bash
python3 -m py_compile main.py && echo "✅ 语法OK" || echo "❌ 语法错误"
```

### 步骤 4: 重启服务

```bash
pkill -f "python3 main.py" || true
sleep 2
cd /home/admin/gemini-audio-service
source venv/bin/activate
nohup python3 main.py > ~/gemini-service.log 2>&1 &
sleep 5
curl http://localhost:8001/health
```

## 如果上面的方法不行

如果上面的方法因为正则表达式或代码结构问题无法正确修复，请使用**完整文件替换方法**（见 `在服务器上创建main.py_最终方案.md`）。

