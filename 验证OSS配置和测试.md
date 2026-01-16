# 验证 OSS 配置和测试图片生成

## ✅ 当前状态

- OSS 配置检查通过
- 服务已启动（进程 138176）
- 健康检查通过

## 下一步：验证 OSS 初始化

在服务器上执行以下命令，检查 OSS 是否成功初始化：

```bash
tail -50 ~/gemini-audio-service.log | grep -E "OSS|oss2|图片生成|Image"
```

应该看到类似输出：
- `✅ OSS 配置成功`
- `OSS Endpoint: oss-cn-beijing.aliyuncs.com`
- `OSS Bucket: geminipicture2`

## 测试图片生成功能

### 1. 获取一个 session_id

从客户端上传音频，或使用已有的 session_id。

### 2. 调用策略分析接口

```bash
SESSION_ID="你的session_id"

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
        print(f'  - image_url: {has_url} {url[:80] if url else \"\"}...')
        print(f'  - image_base64: {has_base64}')
        print()
else:
    print(f'❌ 请求失败: {data.get(\"message\")}')
"
```

### 4. 查看图片生成日志

```bash
tail -100 ~/gemini-audio-service.log | grep -E "图片生成|上传图片|OSS|image_url" | tail -20
```

应该看到：
- `========== 开始生成图片 ==========`
- `上传图片到 OSS: images/{session_id}/{index}.png`
- `✅ 图片上传成功，耗时: X 秒`
- `✅ 图片 URL: https://...`

### 5. 测试图片访问（如果返回了 image_url）

```bash
# 如果返回了 image_url，可以通过 API 访问
curl "http://localhost:8001/api/v1/images/{session_id}/0" -o test_image.png

# 或者直接访问 OSS URL（如果 Bucket 是公共读）
curl "https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/{session_id}/0.png" -o test_image.png
```

## 预期结果

1. ✅ OSS 初始化成功（日志中显示）
2. ✅ 图片生成成功
3. ✅ 图片上传到 OSS 成功
4. ✅ 返回 `image_url` 字段（而不是 `image_base64`）
5. ✅ 可以通过 URL 访问图片

## 故障排查

### 如果图片上传失败

查看详细错误日志：
```bash
tail -100 ~/gemini-audio-service.log | grep -E "错误|Error|失败|Failed|OSS"
```

常见问题：
1. **AccessKey 错误** - 检查 AccessKey 是否正确
2. **Bucket 权限** - 确保 AccessKey 有该 Bucket 的读写权限
3. **网络问题** - 检查服务器是否能访问 OSS

### 如果返回 Base64 而不是 URL

说明 OSS 上传失败，自动降级到 Base64。检查日志找出失败原因。
