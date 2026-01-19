#!/bin/bash
# 配置 Git 代理并提交代码（如果使用代理）

echo "========== 配置代理并提交代码 =========="
echo ""

# 检查是否已有代理配置
PROXY=$(git config --get http.proxy)
if [ -z "$PROXY" ]; then
    echo "⚠️  未检测到代理配置"
    echo "如果需要使用代理，请先配置："
    echo "  git config --global http.proxy http://proxy.example.com:8080"
    echo "  git config --global https.proxy http://proxy.example.com:8080"
    echo ""
    echo "或者切换到 SSH 方式（推荐）："
    echo "  git remote set-url origin git@github.com:liudanmi-tech/gemini-audio-service.git"
    echo ""
    exit 1
fi

echo "当前代理配置:"
echo "  HTTP代理: $(git config --get http.proxy)"
echo "  HTTPS代理: $(git config --get https.proxy)"
echo ""

# 检查 git 状态
echo "检查 Git 状态..."
git status
echo ""

# 添加所有更改
echo "添加所有更改..."
git add .
echo "✅ 已添加所有更改"
echo ""

# 提交更改
echo "提交更改..."
COMMIT_MSG="feat: 增强v0.4技能架构日志输出，显示匹配的技能ID和名称

- 增强技能匹配日志，显示具体匹配到的技能ID和名称
- 增强策略分析生成日志，显示应用的技能详情
- 增强技能执行日志，显示技能名称
- 创建技能信息查看脚本和文档"
git commit -m "$COMMIT_MSG"
echo "✅ 已提交更改"
echo ""

# 推送到 GitHub
echo "推送到 GitHub..."
git push origin main 2>&1 || git push origin master 2>&1
echo ""

echo "========== 完成 =========="
