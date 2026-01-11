# 修复 analyze_audio_async 函数

## 问题

`analyze_audio_async` 函数中仍然有创建 `UploadFile` 的多余代码，需要删除。

## 修复命令

在命令助手中执行：

```bash
cd /home/admin/gemini-audio-service
cp main.py main.py.backup8

# 删除创建 UploadFile 的多余代码
python3 << 'ENDPYTHON'
with open('main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 查找并删除创建 UploadFile 的代码块
lines = content.split('\n')
new_lines = []
skip_until_result = False
in_uploadfile_block = False

for i, line in enumerate(lines):
    if 'async def analyze_audio_async' in line:
        skip_until_result = True
        new_lines.append(line)
    elif skip_until_result:
        # 跳过创建 UploadFile 的代码块
        if '从临时文件创建 UploadFile 对象' in line:
            in_uploadfile_block = True
            continue
        elif in_uploadfile_block:
            if 'new_file = UploadFile' in line:
                in_uploadfile_block = False
                continue
            elif 'with open(temp_file_path' in line or 'file_content = f.read()' in line or 'from io import BytesIO' in line or 'file_obj = BytesIO' in line or 'file_obj.seek(0)' in line:
                continue
            else:
                # 如果遇到 result = await，说明已经过了 UploadFile 创建代码
                if 'result = await analyze_audio_from_path' in line:
                    in_uploadfile_block = False
                    new_lines.append('        # 直接使用临时文件路径调用 analyze_audio_from_path')
                    new_lines.append(line)
                    skip_until_result = False
                else:
                    new_lines.append(line)
        elif 'result = await analyze_audio_from_path' in line:
            # 确保这一行存在
            if line.strip() not in [l.strip() for l in new_lines[-5:]]:
                new_lines.append('        # 直接使用临时文件路径调用 analyze_audio_from_path')
                new_lines.append(line)
            skip_until_result = False
        else:
            new_lines.append(line)
    else:
        new_lines.append(line)

content_new = '\n'.join(new_lines)

# 写入修复后的文件
with open('main.py', 'w', encoding='utf-8') as f:
    f.write(content_new)

print('✅ 文件修复完成')

# 检查语法
import py_compile
py_compile.compile('main.py', doraise=True)
print('✅ 语法检查通过')
ENDPYTHON
```

## 如果上面的方法太复杂，使用 sed 简单修复

```bash
cd /home/admin/gemini-audio-service
cp main.py main.py.backup8

# 使用 sed 删除多余的行
sed -i '/从临时文件创建 UploadFile 对象/,/new_file = UploadFile/d' main.py
sed -i '/from io import BytesIO/d' main.py

# 确保有正确的调用
grep -n "result = await analyze_audio_from_path" main.py

# 检查语法
python3 -m py_compile main.py && echo "✅ 语法OK" || (echo "❌ 语法错误" && cp main.py.backup8 main.py)
```

## 修复日志路径问题

检查日志路径配置：

```bash
grep -n "logging.FileHandler" main.py
```

应该看到：
```python
logging.FileHandler(os.path.expanduser('~/gemini-audio-service.log'))
```

如果是 `/tmp/gemini-audio-service.log`，需要修复。


