#!/bin/bash
# 测试 SSH 连接并推送代码

echo "========== 测试 SSH 连接并推送 =========="
echo ""

# 1. 设置文件权限
echo "1. 设置文件权限..."
chmod 600 ~/.ssh/id_rsa 2>/dev/null
chmod 644 ~/.ssh/id_rsa.pub 2>/dev/null
echo "✅ 文件权限已设置"
echo ""

# 2. 启动 ssh-agent 并添加密钥
echo "2. 启动 ssh-agent 并添加密钥..."
eval "$(ssh-agent -s)" > /dev/null 2>&1
ssh-add ~/.ssh/id_rsa 2>&1
if [ $? -eq 0 ]; then
    echo "✅ SSH 密钥已添加到 ssh-agent"
    ssh-add -l
else
    echo "⚠️  添加密钥失败，但继续尝试..."
fi
echo ""

# 3. 测试 SSH 连接
echo "3. 测试 SSH 连接..."
SSH_OUTPUT=$(ssh -T git@github.com 2>&1)
echo "$SSH_OUTPUT"
echo ""

if echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
    echo "✅ SSH 连接成功！"
    echo ""
    
    # 4. 推送到 GitHub
    echo "4. 推送到 GitHub..."
    BRANCH=$(git branch --show-current)
    echo "当前分支: $BRANCH"
    echo ""
    
    if git push origin $BRANCH; then
        echo ""
        echo "✅ 已成功推送到 GitHub！"
        echo ""
        echo "可以访问查看: https://github.com/liudanmi-tech/gemini-audio-service"
    else
        echo ""
        echo "❌ 推送失败，请检查错误信息"
    fi
else
    echo "❌ SSH 连接失败"
    echo ""
    echo "可能的原因："
    echo "  1. SSH 公钥未添加到 GitHub"
    echo "  2. 公钥内容不完整或格式错误"
    echo "  3. 网络连接问题"
    echo ""
    echo "请确认："
    echo "  1. 访问 https://github.com/settings/keys"
    echo "  2. 检查是否有您的 SSH 公钥"
    echo "  3. 如果没有，点击 'New SSH key' 添加"
    echo "  4. 公钥内容（完整复制）："
    echo "----------------------------------------"
    cat ~/.ssh/id_rsa.pub
    echo "----------------------------------------"
fi

echo ""
echo "========== 完成 =========="
