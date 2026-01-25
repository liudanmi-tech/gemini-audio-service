#!/bin/bash

# 提交代码到Git

echo "🚀 开始提交代码到Git..."
echo ""

# 检查是否在git仓库中
if [ ! -d .git ]; then
    echo "❌ 当前目录不是git仓库"
    exit 1
fi

# 1. 检查状态
echo "📋 步骤1: 检查git状态..."
git status --short | head -20
echo ""

# 2. 添加所有更改
echo "📤 步骤2: 添加所有更改..."
git add -A
echo "✅ 文件已添加到暂存区"
echo ""

# 3. 显示将要提交的文件
echo "📋 步骤3: 将要提交的文件..."
git status --short | head -30
echo ""

# 4. 提交更改
echo "💾 步骤4: 提交更改..."
COMMIT_MESSAGE="修复档案图片上传和显示问题

- 修复OSS图片403错误（添加ACL公共读权限）
- 修复图片上传空响应问题（改进错误处理和日志）
- 优化图片加载逻辑（RemoteImageView URL变化检测）
- 优化保存按钮状态（上传中禁用并显示状态）
- 改进错误提示信息
- 添加详细的调试日志"

git commit -m "$COMMIT_MESSAGE"
if [ $? -eq 0 ]; then
    echo "✅ 代码已提交"
else
    echo "❌ 提交失败"
    exit 1
fi
echo ""

# 5. 推送到远程仓库
echo "📤 步骤5: 推送到远程仓库..."
git push
if [ $? -eq 0 ]; then
    echo "✅ 代码已推送到远程仓库"
else
    echo "⚠️  推送失败，请检查网络连接或远程仓库配置"
    echo "   可以手动执行: git push"
fi
echo ""

echo "========== 完成 =========="
