# 获取 session_id 并测试图片生成

## 1. 验证服务健康状态

```bash
curl http://localhost:8001/health
```

如果返回空，可能是服务有问题。检查服务是否运行：

```bash
ps aux | grep '[p]ython.*main.py'
```

## 2. 获取真实的 session_id

### 方法 1: 从日志中查找

```bash
# 查找最近的 session_id（UUID 格式）
tail -200 ~/gemini-audio-service.log | grep -E "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" | tail -5
```

### 方法 2: 从客户端上传音频

从 iOS 客户端上传一段音频，客户端会返回 session_id。

### 方法 3: 查看任务列表

```bash
curl "http://localhost:8001/api/v1/tasks/sessions?page=1&page_size=10" | python3 -m json.tool
```

这会返回最近的 session_id 列表。

## 3. 使用真实的 session_id 测试

获取到 session_id 后（例如：`49d9d891-6898-4f16-b9e5-fef458f6918a`），执行：

```bash
SESSION_ID="49d9d891-6898-4f16-b9e5-fef458f6918a"  # 替换为真实的 session_id

# 调用策略分析接口
curl -X POST "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/strategies" \
  -H "Content-Type: application/json" -o response.json

# 检查返回数据
python3 -c "
import json
with open('response.json', 'r') as f:
    data = json.load(f)
    
if data.get('code') == 200:
    visual_list = data.get('data', {}).get('visual', [])
    print(f'关键时刻数量: {len(visual_list)}')
    print()
    for i, v in enumerate(visual_list):
        has_url = '✅' if v.get('image_url') else '❌'
        has_base64 = '✅' if v.get('image_base64') else '❌'
        url = v.get('image_url', '')
        print(f'关键时刻 {i+1}:')
        print(f'  - image_url: {has_url} {url[:80] if url else \"\"}...')
        print(f'  - image_base64: {has_base64}')
        print()
else:
    print(f'❌ 请求失败: {data.get(\"message\")}')
    print(f'完整响应: {json.dumps(data, indent=2, ensure_ascii=False)}')
"
```

## 4. 查看图片生成日志

```bash
tail -200 ~/gemini-audio-service.log | grep -E "图片生成|上传图片|OSS|图片上传成功|image_url" | tail -30
```

## 常见错误

### 错误 1: session_id 不存在

如果返回 `Session not found`，说明这个 session_id 不存在或已过期。

### 错误 2: 任务未完成

如果返回错误，可能是音频分析还未完成。先检查任务状态：

```bash
SESSION_ID="你的session_id"
curl "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/status" | python3 -m json.tool
```

如果状态不是 `2`（已完成），需要等待分析完成。
