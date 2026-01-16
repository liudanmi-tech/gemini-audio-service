#!/bin/bash

echo "========== 重新上传修复后的 main.py =========="
scp main.py admin@47.79.254.213:~/gemini-audio-service/main.py

if [ $? -eq 0 ]; then
    echo "✅ main.py 上传成功！"
    echo ""
    echo "========== 在服务器上重启服务 =========="
    echo ""
    echo "SSH 登录服务器后执行："
    echo "  cd ~/gemini-audio-service"
    echo "  source venv/bin/activate"
    echo "  python3 -m py_compile main.py  # 验证语法"
    echo "  pkill -f 'python.*main.py'"
    echo "  sleep 2"
    echo "  nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
    echo "  sleep 3"
    echo "  ps aux | grep '[p]ython.*main.py'"
    echo ""
    echo "========== 验证修复 =========="
    echo "  tail -50 ~/gemini-audio-service.log | grep -E 'OSS|配置成功'"
    echo ""
    echo "========== 然后重新测试图片生成 =========="
    echo "  SESSION_ID=\"3f979f36-d0e6-4877-b86a-2f3291c71230\""
    echo "  curl -X POST \"http://localhost:8001/api/v1/tasks/sessions/\$SESSION_ID/strategies\" \\"
    echo "    -H \"Content-Type: application/json\" -o response.json"
else
    echo "❌ 上传失败"
    exit 1
fi
