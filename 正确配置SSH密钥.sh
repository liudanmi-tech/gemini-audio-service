#!/bin/bash
# 正确配置 SSH 密钥

echo "🔑 开始配置 SSH 密钥..."

# 1. 检查是否已有 SSH 密钥
if [ -f ~/.ssh/id_rsa.pub ]; then
    echo "✅ 已存在 SSH 密钥: ~/.ssh/id_rsa.pub"
else
    echo "📝 生成新的 SSH 密钥..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    echo "✅ SSH 密钥生成完成"
fi

# 2. 复制公钥到服务器
echo ""
echo "📤 复制公钥到服务器..."
echo "⚠️  请输入服务器密码："
ssh-copy-id admin@47.79.254.213

# 3. 测试连接
echo ""
echo "🔍 测试 SSH 连接..."
ssh admin@47.79.254.213 "echo '✅ SSH 连接成功！'"

echo ""
echo "✅ 配置完成！现在可以无密码连接服务器了。"

