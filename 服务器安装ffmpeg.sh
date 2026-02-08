#!/bin/bash
# 在服务器上安装 ffmpeg，解决「建立声音档案」时提取片段 500、声纹剪切失败
# 用法：./服务器安装ffmpeg.sh   （本机执行，通过 SSH 在服务器上安装）

SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

echo "========== 在服务器上安装 ffmpeg =========="
echo "服务器: $SERVER"
echo ""

ssh -o ConnectTimeout=15 "$SERVER" bash -s << 'REMOTE'
set -e
echo "检查是否已安装 ffmpeg..."
if command -v ffmpeg >/dev/null 2>&1; then
  echo "✅ ffmpeg 已安装: $(ffmpeg -version | head -1)"
  exit 0
fi
echo "安装 ffmpeg（需 sudo）..."
sudo apt-get update -qq
sudo apt-get install -y ffmpeg
echo "✅ 安装完成"
ffmpeg -version | head -1
REMOTE

echo ""
echo "========== 完成 =========="
echo "请重新在 App 中「选择音频片段」建立声音档案；若仍失败，请重启应用: ./恢复502_启动应用.sh"
