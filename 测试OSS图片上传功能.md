# 测试 OSS 图片上传功能

## ✅ 当前状态

- ✅ 服务已启动（进程 140193）
- ✅ OSS 配置成功
- ✅ OSS Endpoint: oss-cn-beijing.aliyuncs.com
- ✅ OSS Bucket: geminipicture2

## 测试步骤

### 1. 验证服务健康状态

```bash
curl http://localhost:8001/health
```

应该返回：
```json
{"message":"音频分析服务正在运行","status":"ok"}
```

### 2. 测试图片生成和上传

使用一个已有的 session_id 或从客户端上传音频获取新的 session_id：

```bash
SESSION_ID="你的session_id"

# 调用策略分析接口（这会触发图片生成和上传到 OSS）
curl -X POST "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/strategies" \
  -H "Content-Type: application/json" | python3 -m json.tool > response.json
```

### 3. 检查返回数据

```bash
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
        print(f'  - transcript_index: {v.get(\"transcript_index\")}')
        print(f'  - speaker: {v.get(\"speaker\")}')
        print(f'  - emotion: {v.get(\"emotion\")}')
        print(f'  - image_url: {has_url}')
        if url:
            print(f'    URL: {url[:80]}...')
        print(f'  - image_base64: {has_base64}')
        print()
else:
    print(f'❌ 请求失败: {data.get(\"message\")}')
"
```

### 4. 查看图片生成和上传日志

```bash
tail -100 ~/gemini-audio-service.log | grep -E "图片生成|上传图片|OSS|image_url|图片上传成功" | tail -30
```

应该看到：
- `========== 开始生成图片 ==========`
- `上传图片到 OSS: images/{session_id}/{index}.png`
- `✅ 图片上传成功，耗时: X 秒`
- `✅ 图片 URL: https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/...`

### 5. 验证图片访问

如果返回了 `image_url`，可以通过以下方式访问：

#### 方式 1: 通过 API 访问（推荐，带访问控制）

```bash
curl "http://localhost:8001/api/v1/images/{session_id}/0" -o test_image.png
```

#### 方式 2: 直接访问 OSS URL（如果 Bucket 是公共读）

```bash
curl "https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/{session_id}/0.png" -o test_image.png
```

### 6. 检查 OSS 中的文件

```bash
python3 -c "
import os
from dotenv import load_dotenv
import oss2

load_dotenv()

auth = oss2.Auth(
    os.getenv('OSS_ACCESS_KEY_ID'),
    os.getenv('OSS_ACCESS_KEY_SECRET')
)
bucket = oss2.Bucket(auth, os.getenv('OSS_ENDPOINT'), os.getenv('OSS_BUCKET_NAME'))

print('OSS 中的图片文件:')
for obj in oss2.ObjectIterator(bucket, prefix='images/'):
    print(f'  - {obj.key} ({obj.size} 字节, {obj.last_modified})')
"
```

## 预期结果

1. ✅ 返回的 JSON 中包含 `image_url` 字段（而不是 `image_base64`）
2. ✅ `image_url` 格式：`https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/{session_id}/{index}.png`
3. ✅ 日志显示图片上传成功
4. ✅ 可以通过 URL 访问图片

## 故障排查

### 如果返回 Base64 而不是 URL

说明 OSS 上传失败，自动降级到 Base64。查看详细错误：

```bash
tail -100 ~/gemini-audio-service.log | grep -E "错误|Error|失败|Failed|OSS"
```

### 如果图片上传失败

常见原因：
1. **AccessKey 权限不足** - 确保 AccessKey 有该 Bucket 的读写权限
2. **网络问题** - 检查服务器是否能访问 OSS
3. **Bucket 配置问题** - 检查 Bucket 是否存在且配置正确

### 如果图片访问 404

检查：
1. 文件是否已上传到 OSS
2. session_id 和 image_index 是否正确
3. OSS 文件路径是否正确
