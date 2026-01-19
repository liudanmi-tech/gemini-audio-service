#!/bin/bash
# 将 Git 远程仓库从 HTTPS 切换到 SSH，并提交代码

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
ssh -T git@github.com 2>&1 | head -5
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

# 7. 提交更改
echo "7. 提交更改..."
COMMIT_MSG="feat: 增强v0.4技能架构日志输出，显示匹配的技能ID和名称

- 增强技能匹配日志，显示具体匹配到的技能ID和名称
- 增强策略分析生成日志，显示应用的技能详情
- 增强技能执行日志，显示技能名称
- 创建技能信息查看脚本和文档"
git commit -m "$COMMIT_MSG"
echo "✅ 已提交更改"
echo ""

# 8. 推送到 GitHub
echo "8. 推送到 GitHub..."
git push origin main 2>&1 || git push origin master 2>&1
echo ""

echo "========== 完成 =========="
