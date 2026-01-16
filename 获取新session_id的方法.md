# 获取新的 session_id 的方法

## 问题说明

服务重启后，内存中的任务数据（`tasks_storage`）会丢失，所以旧的 session_id 会失效。

## 解决方法

### 方法 1: 从客户端上传新音频（推荐）

1. 打开 iOS 客户端
2. 上传一段音频
3. 上传成功后，客户端会返回包含新 `session_id` 的响应
4. 使用这个新的 `session_id` 测试图片生成

### 方法 2: 在服务器上直接上传测试音频

如果你有测试音频文件，可以直接上传：

```bash
# 如果有测试音频文件（例如 test.m4a）
curl -X POST "http://localhost:8001/api/v1/audio/upload" \
  -F "file=@test.m4a" \
  -F "title=测试音频" | python3 -m json.tool
```

这会返回包含新 `session_id` 的响应：

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

### 方法 3: 查看任务列表（如果有持久化存储）

```bash
curl -s "http://localhost:8001/api/v1/tasks/sessions?page=1&page_size=10" | python3 -m json.tool
```

## 测试流程

1. **上传音频** → 获取新的 `session_id`
2. **等待分析完成** → 检查任务状态为 `2`（已完成）
3. **调用策略分析** → 触发图片生成和上传到 OSS
4. **检查结果** → 查看返回的 `image_url`

## 完整测试脚本

```bash
# 1. 上传音频（如果有测试文件）
SESSION_ID=$(curl -s -X POST "http://localhost:8001/api/v1/audio/upload" \
  -F "file=@test.m4a" \
  -F "title=测试音频" | python3 -c "import json, sys; print(json.load(sys.stdin)['data']['session_id'])")

echo "新的 session_id: $SESSION_ID"

# 2. 等待分析完成（轮询状态）
while true; do
  STATUS=$(curl -s "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/status" | python3 -c "import json, sys; print(json.load(sys.stdin).get('data', {}).get('status', 0))")
  echo "任务状态: $STATUS"
  if [ "$STATUS" = "2" ]; then
    echo "✅ 分析完成！"
    break
  fi
  sleep 5
done

# 3. 调用策略分析
curl -X POST "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/strategies" \
  -H "Content-Type: application/json" -o response.json

# 4. 检查结果
python3 -c "
import json
with open('response.json', 'r') as f:
    data = json.load(f)
visual_list = data.get('data', {}).get('visual', [])
for i, v in enumerate(visual_list):
    url = v.get('image_url', '')
    print(f'关键时刻 {i+1}: image_url={url[:80] if url else \"❌ 无URL\"}...')
"
```
