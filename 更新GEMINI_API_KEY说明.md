# 更新 GEMINI_API_KEY 说明

## 问题

从日志中看到：
```
API Key: your_gemin... (已隐藏)
```

说明 `.env` 文件中的 `GEMINI_API_KEY` 还是默认值，需要更新为实际的 API Key。

## 解决方法

### 方法 1: 在服务器上直接编辑

```bash
ssh admin@47.79.254.213
cd ~/gemini-audio-service
nano .env
```

找到这一行：
```
GEMINI_API_KEY=your_gemini_api_key_here
```

替换为你的实际 API Key：
```
GEMINI_API_KEY=你的实际API_Key
```

保存退出（Ctrl+X, Y, Enter）

### 方法 2: 在本地更新后重新上传

1. 在本地编辑 `.env` 文件，更新 `GEMINI_API_KEY`
2. 重新上传：
   ```bash
   scp .env admin@47.79.254.213:~/gemini-audio-service/.env
   ```

### 方法 3: 使用 sed 命令快速替换

```bash
ssh admin@47.79.254.213
cd ~/gemini-audio-service

# 替换 GEMINI_API_KEY（将 YOUR_ACTUAL_API_KEY 替换为实际值）
sed -i 's/GEMINI_API_KEY=your_gemini_api_key_here/GEMINI_API_KEY=YOUR_ACTUAL_API_KEY/' .env

# 验证
grep GEMINI_API_KEY .env
```

## 验证

更新后，重启服务并验证：

```bash
# 重启服务
pkill -f 'python.*main.py'
sleep 2
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &

# 查看日志，确认 API Key 已更新
tail -20 ~/gemini-audio-service.log | grep "API Key"
```

应该看到你的实际 API Key 的前几个字符，而不是 "your_gemin..."。
