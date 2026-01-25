#!/bin/bash

# 诊断图片403问题 - 检查服务端和客户端

echo "🔍 开始诊断图片403问题..."
echo ""

echo "========== 1. 检查服务端代码 =========="
echo "检查main.py是否包含ACL设置..."
ssh admin@47.79.254.213 'grep -A 3 "x-oss-object-acl" ~/gemini-audio-service/main.py 2>/dev/null || echo "❌ 未找到ACL设置"'
echo ""

echo "========== 2. 检查服务是否运行 =========="
ssh admin@47.79.254.213 'ps aux | grep "python3 main.py" | grep -v grep || echo "❌ 服务未运行"'
echo ""

echo "========== 3. 检查最近的图片上传日志 =========="
ssh admin@47.79.254.213 'tail -500 ~/gemini-audio-service.log 2>/dev/null | grep -E "收到图片上传|上传图片到 OSS|图片上传成功|图片已设置为公共读|upload.*photo" -i | tail -20 || echo "❌ 未找到相关日志"'
echo ""

echo "========== 4. 检查OSS配置 =========="
ssh admin@47.79.254.213 'grep -E "OSS_|USE_OSS" ~/gemini-audio-service/.env 2>/dev/null | head -5 || echo "❌ 未找到OSS配置"'
echo ""

echo "========== 5. 测试图片URL访问 =========="
echo "测试一个图片URL是否可以访问..."
TEST_URL="https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/067aecd8-3c29-473d-964b-77a524014283/profile_05db3125-d9e5-46da-bbc6-ab8ab89cc81c/0.png"
curl -I "$TEST_URL" 2>&1 | head -10
echo ""

echo "========== 诊断完成 =========="
echo ""
echo "如果看到："
echo "  - ❌ 未找到ACL设置：需要部署修复后的代码"
echo "  - ❌ 服务未运行：需要重启服务"
echo "  - HTTP 403：说明图片权限为私有，需要设置为公共读"
echo "  - HTTP 200：说明图片可以访问，问题可能在客户端"
