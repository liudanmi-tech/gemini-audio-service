#!/bin/bash

# 调用策略分析接口并查看 image_prompt

SESSION_ID="6eb9319c-b556-47be-87dd-e7849ddad53e"

echo "========== 调用策略分析接口 =========="
echo "Session ID: $SESSION_ID"
echo ""

curl -X POST "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/strategies" \
  -H "Content-Type: application/json" | \
  python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
    
    if data.get('code') == 200:
        visual = data.get('data', {}).get('visual', [])
        strategies = data.get('data', {}).get('strategies', [])
        
        print('✅ 策略分析成功！')
        print('')
        print(f'关键时刻数量: {len(visual)}')
        print(f'策略数量: {len(strategies)}')
        print('')
        print('=' * 80)
        
        for i, v in enumerate(visual):
            print(f'关键时刻 {i+1}:')
            print(f'  transcript_index: {v.get(\"transcript_index\")}')
            print(f'  speaker: {v.get(\"speaker\")}')
            print(f'  emotion: {v.get(\"emotion\")}')
            print(f'  subtext: {v.get(\"subtext\")}')
            print(f'  context: {v.get(\"context\")}')
            print(f'  my_inner: {v.get(\"my_inner\")}')
            print(f'  other_inner: {v.get(\"other_inner\")}')
            print('')
            print('  image_prompt (火柴人动画提示词):')
            print('  ' + '-' * 76)
            prompt = v.get('image_prompt', '')
            # 每行缩进并换行
            for line in prompt.split('。'):
                if line.strip():
                    print(f'  {line.strip()}。')
            print('  ' + '-' * 76)
            print('')
        
        print('=' * 80)
        print('')
        print('策略列表:')
        for s in strategies:
            print(f'  - {s.get(\"label\")} ({s.get(\"emoji\")}): {s.get(\"title\")}')
    else:
        print(f'❌ 错误: {data.get(\"message\")}')
        print(json.dumps(data, indent=2, ensure_ascii=False))
except Exception as e:
    print(f'❌ 解析失败: {e}')
    import traceback
    traceback.print_exc()
"
