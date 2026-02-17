#!/bin/bash
# 在本机执行：尝试 SSH 连接并运行服务器诊断
# 若 SSH 成功 → 执行诊断并保存到 服务器诊断输出.txt
# 若 SSH 失败 → 提示使用阿里云 Workbench 手动执行

SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT="$SCRIPT_DIR/服务器诊断输出.txt"
SSH_OPTS="-o ConnectTimeout=15 -o StrictHostKeyChecking=no"

echo "========== SSH 连接测试 =========="
echo "目标: $SERVER"
echo ""

if ssh $SSH_OPTS "$SERVER" "echo 'SSH连接成功'; hostname" 2>&1; then
  echo ""
  echo "✅ SSH 连接成功，开始执行诊断..."
  echo ""
  ssh $SSH_OPTS "$SERVER" "bash -s" < "$SCRIPT_DIR/阿里云远程连接-诊断列表超时.txt" 2>&1 | tee "$OUTPUT"
  echo ""
  echo "========== 完成 =========="
  echo "诊断输出已保存到: $OUTPUT"
else
  echo ""
  echo "❌ SSH 连接失败"
  echo ""
  echo "可能原因："
  echo "  1. 未配置 SSH 密钥（实例使用密钥对登录）"
  echo "  2. 本机网络/代理导致连接超时"
  echo "  3. 安全组未放行 22 端口"
  echo ""
  echo "请改用「阿里云 Workbench 远程连接」："
  echo "  1. 阿里云控制台 → ECS → 实例列表"
  echo "  2. 点击实例「远程连接」→ 选择「通过 Workbench 连接」"
  echo "  3. 若需密码，在控制台：更多 → 密码/密钥 → 重置实例密码 或 修改远程连接密码"
  echo "  4. 连接成功后，打开「阿里云远程连接-诊断列表超时.txt」复制整段命令到终端执行"
fi
