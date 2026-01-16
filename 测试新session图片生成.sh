#!/bin/bash
# 测试新 session 的图片生成功能

SESSION_ID="670a5864-22d2-4978-b996-bce22c61afc5"

echo "========== 测试策略分析接口（包含图片生成） =========="
echo "Session ID: $SESSION_ID"
echo ""

cd ~/gemini-audio-service
source venv/bin/activate

echo "1. 调用策略分析接口..."
echo "   这将会生成图片并上传到 OSS，请稍候..."
echo ""

curl -X POST "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/strategies" \
  -H "Content-Type: application/json" \
  -w "\n\nHTTP状态码: %{http_code}\n总耗时: %{time_total} 秒\n" \
  -o response.json

echo ""
echo "2. 检查返回结果..."
echo ""

python3 << EOF
import json
import sys

try:
    with open('response.json', 'r') as f:
        data = json.load(f)
    
    if data.get('code') == 200:
        print("✅ 策略分析成功！")
        print("")
        
        visual_list = data.get('data', {}).get('visual', [])
        strategies = data.get('data', {}).get('strategies', [])
        
        print(f"关键时刻数量: {len(visual_list)}")
        print(f"策略数量: {len(strategies)}")
        print("")
        
        print("========== 图片生成结果 ==========")
        for i, v in enumerate(visual_list):
            url = v.get('image_url', '')
            base64 = v.get('image_base64', '')
            prompt = v.get('image_prompt', '')
            
            print(f"\n关键时刻 {i+1}:")
            print(f"  transcript_index: {v.get('transcript_index')}")
            print(f"  speaker: {v.get('speaker')}")
            print(f"  emotion: {v.get('emotion')}")
            
            if url:
                print(f"  ✅ image_url: {url[:80]}...")
                print(f"     完整 URL: {url}")
            elif base64:
                print(f"  ✅ image_base64: 大小 {len(base64)} 字符")
            else:
                print(f"  ❌ 无图片数据")
            
            if prompt:
                print(f"  image_prompt: {prompt[:100]}...")
        
        print("")
        print("========== 策略列表 ==========")
        for i, s in enumerate(strategies):
            print(f"策略 {i+1}: {s.get('title', 'N/A')}")
    else:
        print(f"❌ 策略分析失败: {data.get('message', '未知错误')}")
        print(f"   错误详情: {json.dumps(data, indent=2, ensure_ascii=False)}")
        sys.exit(1)
        
except FileNotFoundError:
    print("❌ 未找到 response.json 文件")
    sys.exit(1)
except json.JSONDecodeError as e:
    print(f"❌ JSON 解析失败: {e}")
    print("响应内容:")
    with open('response.json', 'r') as f:
        print(f.read())
    sys.exit(1)
except Exception as e:
    print(f"❌ 处理失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF

echo ""
echo "3. 检查 OSS 中的图片文件..."
echo ""

python3 << 'PYTHON_SCRIPT'
import os
from dotenv import load_dotenv
from pathlib import Path
import oss2

load_dotenv(dotenv_path=Path.home() / 'gemini-audio-service' / '.env')

session_id = "670a5864-22d2-4978-b996-bce22c61afc5"

try:
    auth = oss2.Auth(
        os.getenv('OSS_ACCESS_KEY_ID'),
        os.getenv('OSS_ACCESS_KEY_SECRET')
    )
    bucket = oss2.Bucket(
        auth,
        os.getenv('OSS_ENDPOINT'),
        os.getenv('OSS_BUCKET_NAME')
    )
    
    print(f"检查 OSS 中的图片文件: images/{session_id}/")
    files = list(oss2.ObjectIterator(bucket, prefix=f'images/{session_id}/'))
    
    if files:
        print(f"✅ 找到 {len(files)} 个文件:")
        for obj in files:
            print(f"  ✅ {obj.key} ({obj.size} 字节, {obj.size / 1024:.2f} KB)")
    else:
        print("❌ 没有找到文件（可能上传失败或还未上传）")
        
except Exception as e:
    print(f"❌ 检查失败: {e}")
    import traceback
    traceback.print_exc()

PYTHON_SCRIPT

echo ""
echo "========== 测试完成 =========="
echo ""
echo "如果看到 image_url，可以访问该 URL 查看图片"
echo "如果看到 image_base64，说明 OSS 上传失败，降级为 Base64 返回"
