#!/bin/bash
# 诊断并修复 SSH 连接问题

echo "========== 诊断 SSH 连接问题 =========="
echo ""

# 1. 检查 SSH 密钥文件
echo "1. 检查 SSH 密钥文件..."
if [ -f ~/.ssh/id_rsa ]; then
    echo "✅ SSH 私钥存在"
    ls -lh ~/.ssh/id_rsa
else
    echo "❌ SSH 私钥不存在"
    exit 1
fi

if [ -f ~/.ssh/id_rsa.pub ]; then
    echo "✅ SSH 公钥存在"
    ls -lh ~/.ssh/id_rsa.pub
else
    echo "❌ SSH 公钥不存在"
    exit 1
fi
echo ""

# 2. 检查文件权限
echo "2. 检查文件权限..."
chmod 600 ~/.ssh/id_rsa 2>/dev/null
chmod 644 ~/.ssh/id_rsa.pub 2>/dev/null
echo "✅ 已设置正确的文件权限"
echo ""

# 3. 启动 ssh-agent 并添加密钥
echo "3. 启动 ssh-agent 并添加密钥..."
eval "$(ssh-agent -s)" > /dev/null 2>&1
ssh-add ~/.ssh/id_rsa 2>&1
if [ $? -eq 0 ]; then
    echo "✅ SSH 密钥已添加到 ssh-agent"
else
    echo "⚠️  添加密钥到 ssh-agent 失败，但继续..."
fi
echo ""

# 4. 显示公钥内容（用于确认）
echo "4. 您的 SSH 公钥内容："
echo "----------------------------------------"
cat ~/.ssh/id_rsa.pub
echo "----------------------------------------"
echo ""
echo "⚠️  请确认此公钥已添加到 GitHub："
echo "   https://github.com/settings/keys"
echo ""

# 5. 测试 SSH 连接（详细输出）
echo "5. 测试 SSH 连接（详细模式）..."
ssh -vT git@github.com 2>&1 | grep -E "(Authentications|identity|successfully|denied|Permission)" | head -10
echo ""

# 6. 简单测试
echo "6. 简单连接测试..."
SSH_TEST=$(ssh -T git@github.com 2>&1)
if echo "$SSH_TEST" | grep -q "successfully authenticated"; then
    echo "✅ SSH 连接成功！"
    echo ""
    echo "7. 推送到 GitHub..."
    BRANCH=$(git branch --show-current)
    echo "当前分支: $BRANCH"
    if git push origin $BRANCH; then
        echo "✅ 已成功推送到 GitHub"
    else
        echo "❌ 推送失败"
    fi
else
    echo "❌ SSH 连接失败"
    echo ""
    echo "错误信息:"
    echo "$SSH_TEST"
    echo ""
    echo "请检查："
    echo "  1. 公钥是否已正确添加到 GitHub"
    echo "  2. 公钥内容是否完整（从 ssh-rsa 开始到邮箱结束）"
    echo "  3. 网络连接是否正常"
    echo "  4. 是否使用了 VPN 或代理"
fi

echo ""
echo "========== 完成 =========="
