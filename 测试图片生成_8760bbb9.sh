#!/bin/bash

SESSION_ID="8760bbb9-0f67-41f1-9963-45156c554da5"

echo "========== 测试图片生成和上传到 OSS =========="
echo "Session ID: $SESSION_ID"
echo ""

# 1. 检查任务状态
echo "1. 检查任务状态..."
curl -s "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/status" | python3 -m json.tool
echo ""

# 2. 调用策略分析接口（触发图片生成和上传）
echo "2. 调用策略分析接口（生成图片并上传到 OSS）..."
echo "   这可能需要一些时间（每张图片 5-10 秒）..."
curl -X POST "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/strategies" \
  -H "Content-Type: application/json" -o response.json

echo ""
echo "3. 检查返回数据..."
python3 -c "
import json
with open('response.json', 'r') as f:
    data = json.load(f)
    
if data.get('code') == 200:
    visual_list = data.get('data', {}).get('visual', [])
    print(f'✅ 请求成功！关键时刻数量: {len(visual_list)}')
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
            print(f'    URL: {url}')
        print(f'  - image_base64: {has_base64}')
        if v.get('image_base64'):
            print(f'    Base64 大小: {len(v.get(\"image_base64\", \"\"))} 字符')
        print()
else:
    print(f'❌ 请求失败: {data.get(\"message\")}')
    print(f'完整响应: {json.dumps(data, indent=2, ensure_ascii=False)}')
"

echo ""
echo "4. 查看图片生成和上传日志..."
tail -100 ~/gemini-audio-service.log | grep -E "图片生成|上传图片|OSS|图片上传成功|image_url" | tail -20

echo ""
echo "========== 测试完成 =========="
