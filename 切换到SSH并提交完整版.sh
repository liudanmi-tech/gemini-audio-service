#!/bin/bash
# 切换到 SSH 并提交代码的完整脚本

set -e  # 遇到错误立即退出

echo "========== 切换到 SSH 并提交代码 =========="
echo ""

# 1. 检查当前远程仓库配置
echo "1. 检查当前远程仓库配置..."
git remote -v
echo ""

# 2. 切换到 SSH 方式
echo "2. 切换到 SSH 方式..."
git remote set-url origin git@github.com:liudanmi-tech/gemini-audio-service.git
echo "✅ 已切换到 SSH 方式"
echo ""

# 3. 验证远程仓库配置
echo "3. 验证远程仓库配置..."
git remote -v
echo ""

# 4. 检查 SSH 连接
echo "4. 测试 SSH 连接..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✅ SSH 连接成功"
else
    echo "⚠️  SSH 连接测试失败，但继续执行..."
    echo "如果推送失败，请检查 SSH 密钥配置："
    echo "  - 查看公钥: cat ~/.ssh/id_rsa.pub"
    echo "  - 添加到 GitHub: https://github.com/settings/keys"
fi
echo ""

# 5. 检查 git 状态
echo "5. 检查 Git 状态..."
git status
echo ""

# 6. 添加所有更改
echo "6. 添加所有更改..."
git add .
echo "✅ 已添加所有更改"
echo ""

# 7. 检查是否有更改需要提交
if git diff --cached --quiet; then
    echo "⚠️  没有需要提交的更改"
    echo "检查未跟踪的文件..."
    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo "发现未跟踪的文件，添加中..."
        git add .
        git status
    else
        echo "没有未跟踪的文件，所有更改已提交"
        exit 0
    fi
fi

# 8. 提交更改
echo "7. 提交更改..."
COMMIT_MSG="feat: 增强v0.4技能架构日志输出，显示匹配的技能ID和名称

- 增强技能匹配日志，显示具体匹配到的技能ID和名称
- 增强策略分析生成日志，显示应用的技能详情
- 增强技能执行日志，显示技能名称
- 创建技能信息查看脚本和文档
- 修复main.py中技能信息日志输出"
git commit -m "$COMMIT_MSG"
echo "✅ 已提交更改"
echo ""

# 9. 推送到 GitHub
echo "8. 推送到 GitHub..."
# 尝试推送到 main 分支，如果失败则尝试 master
if git push origin main 2>&1; then
    echo "✅ 已推送到 main 分支"
elif git push origin master 2>&1; then
    echo "✅ 已推送到 master 分支"
else
    echo "❌ 推送失败"
    echo "请检查："
    echo "  1. SSH 密钥是否已添加到 GitHub"
    echo "  2. 网络连接是否正常"
    echo "  3. 分支名称是否正确"
    exit 1
fi
echo ""

echo "========== 完成 =========="
