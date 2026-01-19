#!/bin/bash
# 执行 SSH 切换和代码提交

cd /Users/liudan/Desktop/AI军师/gemini-audio-service

echo "========== 切换到 SSH 并提交代码 =========="
echo ""

# 1. 切换到 SSH 方式
echo "1. 切换到 SSH 方式..."
git remote set-url origin git@github.com:liudanmi-tech/gemini-audio-service.git
echo "✅ 已切换到 SSH 方式"
git remote -v
echo ""

# 2. 测试 SSH 连接
echo "2. 测试 SSH 连接..."
ssh -T git@github.com 2>&1 | head -3
echo ""

# 3. 检查状态并添加更改
echo "3. 检查状态并添加更改..."
git status --short | head -10
git add .
echo "✅ 已添加所有更改"
echo ""

# 4. 提交更改
echo "4. 提交更改..."
git commit -m "feat: 增强v0.4技能架构日志输出，显示匹配的技能ID和名称

- 增强技能匹配日志，显示具体匹配到的技能ID和名称
- 增强策略分析生成日志，显示应用的技能详情和名称
- 增强技能执行日志，显示技能名称
- 创建技能信息查看脚本和文档
- 修复main.py中技能信息日志输出，显示技能名称"
echo "✅ 已提交更改"
echo ""

# 5. 推送到 GitHub
echo "5. 推送到 GitHub..."
BRANCH=$(git branch --show-current)
echo "当前分支: $BRANCH"
git push origin $BRANCH
echo ""

echo "========== 完成 =========="
