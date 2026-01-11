#!/bin/bash
# 诊断服务端问题脚本

echo "=== 1. 查找所有日志文件 ==="
find ~ -name "*gemini*log*" -type f 2>/dev/null
find ~ -name "*.log" -type f -newer ~/gemini-audio-service.log 2>/dev/null | head -10

echo ""
echo "=== 2. 检查 gemini-service.log（技术文档中提到的） ==="
if [ -f ~/gemini-service.log ]; then
    echo "文件存在，查看最后100行："
    tail -n 100 ~/gemini-service.log
    echo ""
    echo "查找1月11日的日志："
    grep "2026-01-11" ~/gemini-service.log | tail -n 50
    echo ""
    echo "查找任务ID："
    grep "5ce813e1-d670-4ef0-b585-9bcdf07f18c7" ~/gemini-service.log
else
    echo "文件不存在"
fi

echo ""
echo "=== 3. 检查服务运行状态 ==="
ps aux | grep "python.*main.py" | grep -v grep

echo ""
echo "=== 4. 检查代码版本（upload_audio_api函数） ==="
cd /home/admin/gemini-audio-service 2>/dev/null || cd ~/gemini-audio-service 2>/dev/null
if [ -f main.py ]; then
    echo "检查 analyze_audio_async 调用（应该在第628行附近）："
    sed -n '625,630p' main.py
    echo ""
    echo "检查 analyze_audio_async 函数定义（应该在第648行附近）："
    sed -n '648,650p' main.py
else
    echo "main.py 文件不存在"
fi

echo ""
echo "=== 5. 检查服务端口 ==="
netstat -tlnp 2>/dev/null | grep 8001 || ss -tlnp 2>/dev/null | grep 8001

echo ""
echo "=== 6. 测试服务健康检查 ==="
curl -s http://localhost:8001/health || echo "服务无响应"
