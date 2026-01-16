# 查找 session_id - 替代方法

## 方法 1: 查看任务列表 API（推荐）

```bash
curl -s "http://localhost:8001/api/v1/tasks/sessions?page=1&page_size=10" | python3 -m json.tool
```

这会返回所有任务的列表，包括 session_id。

## 方法 2: 查看完整的日志（查找关键词）

```bash
# 查找包含 "session" 或 "任务" 的行
tail -1000 ~/gemini-audio-service.log | grep -iE "session|任务|upload|POST" | tail -20

# 或者查找所有包含数字的行（可能包含 session_id）
tail -1000 ~/gemini-audio-service.log | grep -E "[0-9a-f-]{36}" | tail -10
```

## 方法 3: 从客户端上传新音频（最简单）

如果你有 iOS 客户端，最简单的方法是：
1. 打开应用
2. 上传一段音频
3. 上传成功后，客户端会返回 session_id

## 方法 4: 直接上传测试音频到服务器

如果你有测试音频文件，可以直接上传：

```bash
# 如果有测试音频文件（例如 test.m4a）
curl -X POST "http://localhost:8001/api/v1/audio/upload" \
  -F "file=@test.m4a" \
  -F "title=测试音频" | python3 -m json.tool
```

这会返回包含新 session_id 的响应。

## 方法 5: 查看内存中的任务数据

如果服务正在运行，任务数据可能在内存中。可以查看代码中 `tasks_storage` 的内容（但这需要修改代码添加调试接口）。

## 快速测试脚本

```bash
cat > ~/get_session_id.sh << 'EOF'
#!/bin/bash

echo "========== 方法 1: 从 API 获取 =========="
curl -s "http://localhost:8001/api/v1/tasks/sessions?page=1&page_size=5" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data.get('code') == 200:
        sessions = data.get('data', {}).get('sessions', [])
        if sessions:
            print('找到的 session_id:')
            for s in sessions:
                print(f\"  {s.get('session_id')} (状态: {s.get('status')}, 标题: {s.get('title', 'N/A')})\")
        else:
            print('  没有找到任务')
    else:
        print(f\"  API 错误: {data.get('message')}\")
except Exception as e:
    print(f\"  API 请求失败: {e}\")
"

echo ""
echo "========== 方法 2: 从日志查找 =========="
tail -1000 ~/gemini-audio-service.log | grep -oE "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" | sort -u | tail -5

echo ""
echo "========== 如果没有找到，建议从客户端上传新音频获取 session_id =========="
EOF

chmod +x ~/get_session_id.sh
~/get_session_id.sh
```
