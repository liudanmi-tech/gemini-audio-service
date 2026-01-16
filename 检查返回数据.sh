#!/bin/bash

echo "========== 检查返回数据 =========="
python3 -c "
import json
with open('response.json', 'r') as f:
    data = json.load(f)
    
if data.get('code') == 200:
    visual_list = data.get('data', {}).get('visual', [])
    print(f'关键时刻数量: {len(visual_list)}')
    print()
    
    for i, v in enumerate(visual_list):
        has_image = '✅' if v.get('image_base64') else '❌'
        image_size = len(v.get('image_base64', '')) if v.get('image_base64') else 0
        print(f'关键时刻 {i+1}:')
        print(f'  - transcript_index: {v.get(\"transcript_index\")}')
        print(f'  - speaker: {v.get(\"speaker\")}')
        print(f'  - emotion: {v.get(\"emotion\")}')
        print(f'  - 图片: {has_image} (Base64 大小: {image_size} 字符)')
        if image_size > 0:
            print(f'  - 图片前50字符: {v.get(\"image_base64\", \"\")[:50]}...')
        print()
else:
    print(f'❌ 请求失败: {data.get(\"message\")}')
    print(f'完整响应: {json.dumps(data, indent=2, ensure_ascii=False)}')
"

echo ""
echo "========== 查看图片生成日志 =========="
tail -100 ~/gemini-audio-service.log | grep -E "图片生成|关键时刻|image_base64|gemini-2.5-flash-image" | tail -20
