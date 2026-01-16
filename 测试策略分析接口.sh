#!/bin/bash

# 测试策略分析接口并查看 image_prompt

echo "========== 获取任务列表 =========="
echo "查找已完成分析的任务（status=archived）..."
curl -s "http://47.79.254.213:8001/api/v1/tasks/sessions?page=1&page_size=10" | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
if data.get('code') == 200 and data.get('data'):
    sessions = data['data'].get('sessions', [])
    archived = [s for s in sessions if s.get('status') == 'archived']
    if archived:
        print(f'找到 {len(archived)} 个已完成的任务:')
        for s in archived[:3]:
            print(f\"  - {s.get('session_id')}: {s.get('title')} (状态: {s.get('status')})\")
        print(f\"\\n使用最新的任务ID测试:\\n  {archived[0].get('session_id')}\")
    else:
        print('没有找到已完成的任务，请等待音频分析完成')
else:
    print('获取任务列表失败')
"

echo ""
echo "========== 请输入 session_id 进行测试 =========="
echo "或者直接执行："
echo "curl -X POST \"http://47.79.254.213:8001/api/v1/tasks/sessions/{session_id}/strategies\" | python3 -m json.tool"
