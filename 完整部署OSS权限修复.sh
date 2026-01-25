#!/bin/bash

# 完整部署OSS权限修复 - 包括上传代码、验证、重启服务

echo "🚀 开始部署OSS权限修复..."
echo ""

# 1. 上传代码
echo "📤 步骤1: 上传修复后的代码..."
scp main.py admin@47.79.254.213:~/gemini-audio-service/
if [ $? -eq 0 ]; then
    echo "✅ 代码上传成功"
else
    echo "❌ 代码上传失败"
    exit 1
fi
echo ""

# 2. 验证代码已更新
echo "🔍 步骤2: 验证代码已更新..."
ssh admin@47.79.254.213 'grep -A 3 "x-oss-object-acl" ~/gemini-audio-service/main.py' | grep -q "public-read"
if [ $? -eq 0 ]; then
    echo "✅ 代码已包含ACL设置"
else
    echo "❌ 代码未包含ACL设置，请检查"
    exit 1
fi
echo ""

# 3. 停止旧服务
echo "🛑 步骤3: 停止旧服务..."
ssh admin@47.79.254.213 'pkill -f "python3 main.py" && sleep 2 && echo "✅ 旧服务已停止" || echo "⚠️  未找到运行中的服务"'
echo ""

# 4. 启动新服务
echo "🚀 步骤4: 启动新服务..."
ssh admin@47.79.254.213 'cd ~/gemini-audio-service && nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &'
sleep 3
echo "✅ 服务已启动"
echo ""

# 5. 验证服务运行
echo "🔍 步骤5: 验证服务运行..."
ssh admin@47.79.254.213 'ps aux | grep "python3 main.py" | grep -v grep'
if [ $? -eq 0 ]; then
    echo "✅ 服务正在运行"
else
    echo "❌ 服务未运行，请检查日志"
    ssh admin@47.79.254.213 'tail -30 ~/gemini-audio-service.log'
    exit 1
fi
echo ""

# 6. 查看启动日志
echo "📋 步骤6: 查看启动日志..."
ssh admin@47.79.254.213 'tail -20 ~/gemini-audio-service.log'
echo ""

echo "========== 部署完成 =========="
echo ""
echo "✅ 修复后的代码已部署"
echo "✅ 服务已重启"
echo ""
echo "📝 下一步："
echo "   1. 在客户端重新上传一张新图片"
echo "   2. 检查服务端日志，应该看到'图片已设置为公共读权限'"
echo "   3. 新上传的图片应该可以正常访问"
echo ""
echo "🔍 查看服务端日志："
echo "   ssh admin@47.79.254.213 'tail -f ~/gemini-audio-service.log'"
