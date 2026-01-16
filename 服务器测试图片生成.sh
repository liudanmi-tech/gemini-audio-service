#!/bin/bash
# 在服务器上执行此脚本

cd ~/gemini-audio-service
source venv/bin/activate

echo "========== 测试 Gemini 图片生成 API =========="
echo ""

# 加载环境变量
export $(grep -v '^#' .env | xargs)

echo "1. 检查 API Key 配置..."
if [ -z "$GEMINI_API_KEY" ]; then
    echo "❌ 未找到 GEMINI_API_KEY"
    exit 1
fi
echo "✅ 找到 API Key: ${GEMINI_API_KEY:0:10}...${GEMINI_API_KEY: -4}"
echo "   API Key 长度: ${#GEMINI_API_KEY} 字符"
echo ""

echo "2. 测试 API Key 连接..."
python3 -c "
from google import genai as genai_new
import os

api_key = os.getenv('GEMINI_API_KEY')
try:
    client = genai_new.Client(api_key=api_key)
    print('✅ API Key 连接成功')
except Exception as e:
    print(f'❌ API Key 连接失败: {e}')
    exit(1)
"

echo ""
echo "3. 测试图片生成（简单测试）..."
python3 -c "
from google import genai as genai_new
from google.genai import types as genai_types
import os
import time

api_key = os.getenv('GEMINI_API_KEY')

try:
    client = genai_new.Client(api_key=api_key)
    
    config = genai_types.GenerateContentConfig(
        image_config=genai_types.ImageConfig(aspect_ratio='4:3')
    )
    
    test_prompt = '米色背景，极简火柴人线稿，左侧为用户，右侧为对方，两人面对面站立'
    
    print(f'测试提示词: {test_prompt}')
    print('调用模型: gemini-2.5-flash-image')
    print('正在生成图片...')
    
    start_time = time.time()
    response = client.models.generate_content(
        model='gemini-2.5-flash-image',
        contents=[test_prompt],
        config=config
    )
    elapsed_time = time.time() - start_time
    
    print(f'✅ 图片生成成功！耗时: {elapsed_time:.2f} 秒')
    
    image_found = False
    for part in response.parts:
        if part.inline_data is not None:
            image_size = len(part.inline_data.data)
            print(f'✅ 图片数据大小: {image_size} 字节 ({image_size / 1024:.2f} KB)')
            image_found = True
            break
    
    if not image_found:
        print('⚠️ 响应中没有找到图片数据')
    
except Exception as e:
    error_str = str(e)
    print(f'❌ 图片生成失败: {error_str[:500]}')
    
    if '429' in error_str or 'RESOURCE_EXHAUSTED' in error_str:
        print('')
        print('⚠️ 检测到配额超限错误 (429)')
        print('')
        print('可能的原因:')
        print('  1. API Key 仍关联到免费层项目')
        print('  2. 配额需要时间刷新（等待 10-30 分钟）')
        print('  3. 未启用图片生成 API 的付费配额')
        print('')
        print('解决步骤:')
        print('  1. 访问 https://aistudio.google.com/apikey 检查 API Key')
        print('  2. 访问 https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com/quotas 检查配额')
        print('  3. 确认已启用 Generative Language API')
        print('  4. 等待几分钟后重试')
    exit(1)
"

echo ""
echo "========== 测试完成 =========="
