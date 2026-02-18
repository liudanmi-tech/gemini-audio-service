#!/bin/bash
# 在阿里云 Workbench 中执行，诊断 session ff15831b 的图片不显示问题
# 阿里云控制台 → ECS → 远程连接 → Workbench → 粘贴整段执行

SESSION_ID="${1:-ff15831b-523a-428a-8aeb-009ba63a9e9a}"

cd ~/gemini-audio-service && source venv/bin/activate

echo "========== 图片不显示诊断：session $SESSION_ID =========="
echo ""

echo "=== 1. 数据库 strategy_analysis 中的 visual_data ==="
python3 scripts/check_visual_data.py "$SESSION_ID"

echo ""
echo "=== 2. 获取策略 API 返回（需 JWT，此处用 curl 模拟）==="
echo "请在 App 中打开该任务的策略页，触发请求后执行下面命令查看日志："
echo "  tail -100 ~/gemini-audio-service.log | grep -E '\[策略-图片\]|\[策略返回\]|visual\['
"
echo "=== 3. 查看最近策略/图片相关日志 ==="
tail -200 ~/gemini-audio-service.log 2>/dev/null | grep -E "\[策略-图片\]|\[策略返回\]|策略流程|visual\[|image_url|image_base64" | tail -30

echo ""
echo "=== 4. 图片 API 路由与 OSS 配置 ==="
grep -E "USE_OSS|OSS_|images/" main.py | head -10

echo ""
echo "=== 5. 健康检查 ==="
curl -sf --max-time 5 http://127.0.0.1:8000/health && echo " ✅" || echo " ❌ 失败"

echo ""
echo "========== 诊断完成 =========="
echo ""
echo "若 visual 中 image_base64 有值而 image_url 为空：前端已支持 Base64 回退，请确保 iOS App 已更新"
echo "若 visual 中 image_url 为 OSS 路径：前端会转为 API URL，需确认 JWT 已携带"
