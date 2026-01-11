# 修复服务器 main.py - 最简单方法（推荐）

## 在命令助手中执行以下命令

**执行用户**：`admin`  
**执行路径**：`/home/admin/gemini-audio-service`

### 完整命令（一次性执行）

```bash
cd /home/admin/gemini-audio-service && \
cp main.py main.py.backup7 && \
sed -i 's/result = await analyze_audio(new_file)/result = await analyze_audio_from_path(temp_file_path, file_filename)/g' main.py && \
python3 -m py_compile main.py && echo "✅ 语法OK" || (echo "❌ 语法错误，恢复备份" && cp main.py.backup7 main.py) && \
pkill -f "python3 main.py" || true && \
sleep 2 && \
source venv/bin/activate && \
nohup python3 main.py > ~/gemini-service.log 2>&1 & \
sleep 5 && \
curl http://localhost:8001/health
```

### 分步执行（如果上面的命令太长）

#### 步骤 1: 备份并修复

```bash
cd /home/admin/gemini-audio-service
cp main.py main.py.backup7
sed -i 's/result = await analyze_audio(new_file)/result = await analyze_audio_from_path(temp_file_path, file_filename)/g' main.py
```

#### 步骤 2: 检查语法

```bash
python3 -m py_compile main.py
```

如果语法错误，恢复备份：
```bash
cp main.py.backup7 main.py
```

#### 步骤 3: 重启服务

```bash
pkill -f "python3 main.py" || true
sleep 2
source venv/bin/activate
nohup python3 main.py > ~/gemini-service.log 2>&1 &
sleep 5
curl http://localhost:8001/health
```

## 说明

这个方法只修复了最关键的一行代码：
- **原来**：`result = await analyze_audio(new_file)`
- **修复后**：`result = await analyze_audio_from_path(temp_file_path, file_filename)`

这应该能解决 "I/O operation on closed file" 错误。

如果修复后还有其他问题，请查看日志：
```bash
tail -50 ~/gemini-audio-service.log
```

