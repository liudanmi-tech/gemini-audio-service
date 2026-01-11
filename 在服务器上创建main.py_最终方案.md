# 在服务器上创建修复后的 main.py - 最终方案

## 推荐方法：使用 base64 编码（分步执行）

由于文件较大（29KB），base64 编码后约 40KB，可能超过命令助手的单次输入限制。

### 方案：分两步执行

#### 步骤 1: 在本地生成 base64 编码文件

在你的 Mac 终端执行：

```bash
cd ~/Desktop/AI军师/gemini-audio-service
python3 << 'PYEOF'
import base64
with open('main.py', 'rb') as f:
    content = f.read()
encoded = base64.b64encode(content).decode('utf-8')
with open('main.py.base64.txt', 'w') as f:
    f.write(encoded)
print(f"✅ Base64 编码完成，已保存到 main.py.base64.txt")
PYEOF
```

#### 步骤 2: 在命令助手中执行（需要分段）

由于 base64 内容太长，建议使用以下方法：

**方法 A: 使用 Python 脚本读取 base64 字符串（如果命令助手支持长文本）**

在命令助手中执行：

```bash
cd /home/admin/gemini-audio-service
cp main.py main.py.backup6

# 这里需要粘贴 base64 编码的内容（从 main.py.base64.txt 文件复制）
# 由于内容太长，可能需要分段处理
python3 << 'ENDPYTHON'
import base64

# 粘贴 base64 编码的内容（从 main.py.base64.txt 复制）
encoded_content = """
这里粘贴 base64 编码的内容
"""

# 解码并写入文件
content = base64.b64decode(encoded_content).decode('utf-8')
with open('main.py', 'w', encoding='utf-8') as f:
    f.write(content)

print('✅ 文件已写入')

# 检查语法
import py_compile
py_compile.compile('main.py', doraise=True)
print('✅ 语法检查通过')
ENDPYTHON
```

**方法 B: 如果命令助手不支持长文本，使用 curl 从外部获取（需要先上传 base64 文件到某个可访问的地方）**

## 更实用的方法：直接修复关键部分

如果上面的方法不行，我们可以只修复关键部分（`analyze_audio_async` 函数），而不是替换整个文件。

### 只修复 analyze_audio_async 函数

在命令助手中执行：

```bash
cd /home/admin/gemini-audio-service
cp main.py main.py.backup7

# 修复 analyze_audio_async 函数
python3 << 'ENDPYTHON'
import re

with open('main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复函数调用：将 analyze_audio(new_file) 改为 analyze_audio_from_path
old_call = 'result = await analyze_audio(new_file)'
new_call = 'result = await analyze_audio_from_path(temp_file_path, file_filename)'

if old_call in content:
    content = content.replace(old_call, new_call)
    print('✅ 已修复函数调用')
else:
    print('ℹ️  函数调用可能已经修复过了')

# 删除创建 UploadFile 的代码（不再需要）
old_create = '''        # 从临时文件创建 UploadFile 对象
        with open(temp_file_path, 'rb') as f:
            file_content = f.read()
        
        # 创建新的 UploadFile 对象
        from io import BytesIO
        file_obj = BytesIO(file_content)
        file_obj.seek(0)  # 确保位置在开头
        
        # 创建 UploadFile 对象
        new_file = UploadFile(
            filename=file_filename,
            file=file_obj
        )
        
        result = await analyze_audio_from_path(temp_file_path, file_filename)'''

new_create = '''        # 直接使用临时文件路径调用 analyze_audio_from_path
        result = await analyze_audio_from_path(temp_file_path, file_filename)'''

if old_create in content:
    content = content.replace(old_create, new_create)
    print('✅ 已删除不必要的 UploadFile 创建代码')
elif 'result = await analyze_audio_from_path(temp_file_path, file_filename)' in content:
    print('ℹ️  代码可能已经修复过了')

with open('main.py', 'w', encoding='utf-8') as f:
    f.write(content)

print('✅ 文件修复完成')

# 检查语法
import py_compile
py_compile.compile('main.py', doraise=True)
print('✅ 语法检查通过')
ENDPYTHON
```

这个方法只修复关键部分，不需要替换整个文件。


