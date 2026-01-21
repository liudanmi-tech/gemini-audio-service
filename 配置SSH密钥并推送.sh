#!/bin/bash
# 配置 SSH 密钥并推送到 GitHub

echo "========== 配置 SSH 密钥并推送 =========="
echo ""

# 1. 检查是否有 SSH 密钥
echo "1. 检查 SSH 密钥..."
if [ -f ~/.ssh/id_rsa ]; then
    echo "✅ 找到 SSH 私钥: ~/.ssh/id_rsa"
    if [ -f ~/.ssh/id_rsa.pub ]; then
        echo "✅ 找到 SSH 公钥: ~/.ssh/id_rsa.pub"
        echo ""
        echo "📋 您的 SSH 公钥内容："
        echo "----------------------------------------"
        cat ~/.ssh/id_rsa.pub
        echo "----------------------------------------"
        echo ""
        echo "⚠️  请将上面的公钥内容添加到 GitHub："
        echo "   1. 访问: https://github.com/settings/keys"
        echo "   2. 点击 'New SSH key'"
        echo "   3. 粘贴上面的公钥内容"
        echo "   4. 点击 'Add SSH key'"
        echo ""
        read -p "已添加到 GitHub 了吗？(y/n): " answer
        if [ "$answer" != "y" ]; then
            echo "请先添加 SSH 公钥到 GitHub，然后重新运行此脚本"
            exit 1
        fi
    else
        echo "❌ 未找到 SSH 公钥，需要生成"
        exit 1
    fi
else
    echo "❌ 未找到 SSH 密钥，需要生成"
    echo ""
    echo "正在生成新的 SSH 密钥..."
    read -p "请输入您的 GitHub 邮箱: " email
    if [ -z "$email" ]; then
        echo "❌ 邮箱不能为空"
        exit 1
    fi
    
    ssh-keygen -t rsa -b 4096 -C "$email" -f ~/.ssh/id_rsa -N ""
    echo "✅ SSH 密钥已生成"
    echo ""
    echo "📋 您的 SSH 公钥内容："
    echo "----------------------------------------"
    cat ~/.ssh/id_rsa.pub
    echo "----------------------------------------"
    echo ""
    echo "⚠️  请将上面的公钥内容添加到 GitHub："
    echo "   1. 访问: https://github.com/settings/keys"
    echo "   2. 点击 'New SSH key'"
    echo "   3. 粘贴上面的公钥内容"
    echo "   4. 点击 'Add SSH key'"
    echo ""
    read -p "已添加到 GitHub 了吗？(y/n): " answer
    if [ "$answer" != "y" ]; then
        echo "请先添加 SSH 公钥到 GitHub，然后重新运行此脚本"
        exit 1
    fi
fi

# 2. 测试 SSH 连接
echo ""
echo "2. 测试 SSH 连接..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✅ SSH 连接成功"
else
    echo "❌ SSH 连接失败"
    echo "请检查："
    echo "  1. SSH 公钥是否已添加到 GitHub"
    echo "  2. 网络连接是否正常"
    exit 1
fi

# 3. 推送到 GitHub
echo ""
echo "3. 推送到 GitHub..."
BRANCH=$(git branch --show-current)
echo "当前分支: $BRANCH"
if git push origin $BRANCH; then
    echo "✅ 已成功推送到 GitHub"
else
    echo "❌ 推送失败"
    exit 1
fi

echo ""
echo "========== 完成 =========="
