#!/bin/bash
# Gemini 接口完整测试 - 在服务器上执行
# 用法：cd ~/gemini-audio-service && bash scripts/test_gemini_full.sh
# 或通过阿里云 Workbench 远程连接后粘贴执行

set -e
cd ~/gemini-audio-service
source venv/bin/activate 2>/dev/null || true

echo "========== Gemini 接口诊断 =========="
echo ""

# 1. 读取 API Key
API_KEY=$(grep GEMINI_API_KEY .env 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'" | head -1)
if [ -z "$API_KEY" ]; then
  echo "❌ 未找到 GEMINI_API_KEY"
  exit 1
fi
echo "✅ GEMINI_API_KEY 已加载（前8位: ${API_KEY:0:8}...）"
echo ""

# 2. curl 测试 models 接口
echo "=== 2. curl 测试 models 接口（15秒超时）==="
if curl -sf --max-time 15 "https://generativelanguage.googleapis.com/v1beta/models?key=$API_KEY" | grep -q "models"; then
  echo "✅ models 接口可达"
else
  echo "❌ models 接口超时或失败（Gemini API 可能不可达）"
fi
echo ""

# 3. test_gemini_connection.py
echo "=== 3. test_gemini_connection.py（list_models + generate_content）==="
if timeout 45 python3 scripts/test_gemini_connection.py 2>&1; then
  echo ""
  echo "✅ 基础接口测试通过"
else
  echo ""
  echo "❌ 基础接口测试失败"
fi
echo ""

# 4. test_gemini_file_upload.py（60秒超时）
echo "=== 4. test_gemini_file_upload.py（文件上传，60秒超时）==="
if timeout 65 python3 scripts/test_gemini_file_upload.py 2>&1; then
  echo ""
  echo "✅ 文件上传测试通过"
else
  echo ""
  echo "❌ 文件上传测试失败或超时"
fi
echo ""
echo "========== 诊断完成 =========="
