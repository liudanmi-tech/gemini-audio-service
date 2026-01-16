# 查找 session_id 的方法

## 方法 1: 从日志中查找（最简单）

session_id 是 UUID 格式（例如：`49d9d891-6898-4f16-b9e5-fef458f6918a`），在日志中搜索：

```bash
# 查找最近的 session_id
tail -500 ~/gemini-audio-service.log | grep -oE "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" | sort -u | tail -5
```

或者更简单的方式：

```bash
# 查找包含 "session" 或 "任务" 的行
tail -500 ~/gemini-audio-service.log | grep -iE "session|任务.*分析完成" | tail -10
```

## 方法 2: 查看任务列表 API

```bash
# 获取最近的任务列表
curl -s "http://localhost:8001/api/v1/tasks/sessions?page=1&page_size=10" | python3 -m json.tool
```

这会返回类似这样的 JSON：

```json
{
  "code": 200,
  "data": {
    "sessions": [
      {
        "session_id": "49d9d891-6898-4f16-b9e5-fef458f6918a",
        "title": "测试音频",
        "status": 2,
        "created_at": "2026-01-14T20:00:00"
      }
    ]
  }
}
```

## 方法 3: 从客户端获取（推荐）

### iOS 客户端

1. 打开 iOS 应用
2. 上传一段音频
3. 上传成功后，客户端会返回包含 `session_id` 的响应
4. 或者在应用的日志/调试信息中查看

### 查看客户端日志

如果客户端有日志输出，查找包含 "session_id" 或 "sessionId" 的行。

## 方法 4: 查看上传请求日志

```bash
# 查找音频上传相关的日志
tail -500 ~/gemini-audio-service.log | grep -E "收到音频上传请求|upload|POST.*audio" | tail -10
```

上传请求的日志中通常会包含 session_id。

## 方法 5: 直接上传新音频获取 session_id

如果找不到已有的 session_id，可以上传新的音频：

### 在服务器上测试上传

```bash
# 如果有测试音频文件
curl -X POST "http://localhost:8001/api/v1/audio/upload" \
  -F "file=@test_audio.m4a" \
  -F "title=测试音频" | python3 -m json.tool
```

这会返回包含 `session_id` 的响应：

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "session_id": "新的session_id",
    "title": "测试音频",
    "created_at": "..."
  }
}
```

## 快速查找脚本

创建一个快速查找脚本：

```bash
cat > ~/find_session_id.sh << 'EOF'
#!/bin/bash

echo "========== 查找最近的 session_id =========="
echo ""

echo "方法 1: 从日志中查找 UUID"
tail -500 ~/gemini-audio-service.log | grep -oE "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" | sort -u | tail -5

echo ""
echo "方法 2: 从任务列表 API 获取"
curl -s "http://localhost:8001/api/v1/tasks/sessions?page=1&page_size=5" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data.get('code') == 200:
        sessions = data.get('data', {}).get('sessions', [])
        for s in sessions:
            print(f\"  - {s.get('session_id')} (状态: {s.get('status')}, 标题: {s.get('title', 'N/A')})\")
    else:
        print(f\"  API 返回错误: {data.get('message')}\")
except:
    print(\"  API 请求失败\")
"
EOF

chmod +x ~/find_session_id.sh
~/find_session_id.sh
```

## 使用找到的 session_id

找到 session_id 后，使用它测试图片生成：

```bash
SESSION_ID="你找到的session_id"

# 检查任务状态
curl -s "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/status" | python3 -m json.tool

# 如果状态是 2（已完成），调用策略分析
curl -X POST "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/strategies" \
  -H "Content-Type: application/json" | python3 -m json.tool > response.json
```
