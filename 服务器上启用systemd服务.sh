#!/bin/bash
# 在服务器上执行：安装 systemd 单元并启用，实现开机自启与 systemctl restart
# 用法：在服务器上 cd ~/gemini-audio-service && bash 服务器上启用systemd服务.sh
# 或从本机 scp 到服务器后 ssh 执行

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
SVC="gemini-audio-service"

# 若用户名/路径不是 admin、/home/admin，请先修改 systemd/gemini-audio-service.service 中的 User 与路径
sudo cp "$DIR/systemd/gemini-audio-service.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable "$SVC"
sudo systemctl start "$SVC"
sudo systemctl status "$SVC" --no-pager

echo ""
echo "之后可用: sudo systemctl restart $SVC  重启服务"
