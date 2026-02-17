# 轮询 HTTP 0 排查结果

## 根因

**后端服务 (uvicorn) 已停止运行**，导致：
- Nginx 将请求转发到 `127.0.0.1:8000` 时无法连接
- 返回 **502 Bad Gateway**（当 Nginx 能返回错误页时）
- 或客户端收不到 HTTP 响应，表现为 **HTTP 0**（连接被重置或超时）

## 排查过程

| 检查项 | 结果 |
|--------|------|
| 服务器根路径 | ✓ 200（Nginx 正常） |
| auth/send-code | ✗ 502（后端宕机） |
| auth/login | ✗ 502 |
| uvicorn 进程 | ✗ 无 |
| 8000 端口 | ✗ 无监听 |

## 已执行修复

已通过 SSH 在服务器上重启服务：
```bash
cd ~/gemini-audio-service
nohup venv/bin/python3 main.py >> ~/gemini-audio-service.log 2>&1 &
```

**验证结果**：send-code、login、status 接口均已恢复正常。

---

## 建议：配置进程守护

当前使用 `nohup` 启动，进程崩溃后不会自动恢复。建议配置 **systemd** 或 **supervisor** 实现自动重启。

### systemd 示例

创建 `/etc/systemd/system/gemini-audio.service`：
```ini
[Unit]
Description=Gemini Audio Service
After=network.target

[Service]
Type=simple
User=admin
WorkingDirectory=/home/admin/gemini-audio-service
ExecStart=/home/admin/gemini-audio-service/venv/bin/python3 main.py
Restart=always
RestartSec=5
StandardOutput=append:/home/admin/gemini-audio-service.log
StandardError=append:/home/admin/gemini-audio-service.log

[Install]
WantedBy=multi-user.target
```

启用并启动：
```bash
sudo systemctl daemon-reload
sudo systemctl enable gemini-audio
sudo systemctl start gemini-audio
```

---

## 后续若再次出现 HTTP 0

1. SSH 登录服务器，执行：`ps aux | grep main.py`
2. 若无进程，执行：`cd ~/gemini-audio-service && nohup venv/bin/python3 main.py >> ~/gemini-audio-service.log 2>&1 &`
3. 查看崩溃原因：`tail -100 ~/gemini-audio-service.log`
