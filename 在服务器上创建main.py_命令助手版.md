# 在服务器上创建 main.py（命令助手版）

## 方法：使用 base64 编码传输

由于文件较大（856行，29KB），使用 base64 编码在命令助手中传输。

### 步骤 1: 在本地生成 base64 编码

在你的 Mac 终端执行：

```bash
cd ~/Desktop/AI军师/gemini-audio-service
python3 -c "import base64; content = open('main.py', 'rb').read(); encoded = base64.b64encode(content).decode('utf-8'); print(encoded)" > main.py.base64
```

这会生成一个 `main.py.base64` 文件，包含 base64 编码的内容。

### 步骤 2: 在命令助手中执行

1. 打开阿里云控制台 → 命令助手
2. 点击"执行命令"
3. 填写：
   - 命令名称：`创建修复后的 main.py`
   - 命令内容：
   ```bash
   cd /home/admin/gemini-audio-service
   cp main.py main.py.backup6
   
   # 这里需要粘贴 base64 编码的内容
   # 由于内容太长，建议分两步：
   # 1. 先创建一个 Python 脚本文件
   # 2. 然后执行脚本
   ```
   - 执行用户：`admin`
   - 执行路径：留空
   - 超时时间：`120`

## 更简单的方法：直接读取本地文件并生成命令

由于 base64 编码后的内容可能太长，我建议使用另一种方法：

### 方法：使用 Python 脚本分段写入

在命令助手中执行以下 Python 脚本（我会提供完整的脚本）：

```python
# 这个脚本会读取 base64 编码的内容并写入文件
# 但由于内容太长，需要分段处理
```

## 推荐：使用 Python 脚本直接写入（最简单）

由于文件较大，我建议创建一个 Python 脚本，在服务器上直接生成文件内容。

