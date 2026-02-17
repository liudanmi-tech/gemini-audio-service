# API 无响应排查说明

## 现象
- 手机浏览器访问 `http://47.79.254.213` 显示 **OK**
- 发送验证码、任务列表等 API 请求 **30 秒超时，返回空响应**

## 原因分析

| 路径 | 处理方 | 说明 |
|------|--------|------|
| `/` | Nginx 直接返回 | 显示 OK，说明 Nginx 正常 |
| `/api/v1/*` | Nginx → 127.0.0.1:8000 (uvicorn) | 若后端宕机，代理无响应，客户端超时 |

**结论**：根路径 OK 而 API 超时，通常是 **Python 后端 (main.py) 未运行或崩溃**。

---

## 解决步骤

### 方式一：SSH 执行诊断脚本（推荐）

在 **Mac 终端**执行（需能 SSH 到服务器）：
```bash
cd /Users/liudan/Desktop/AI军师/gemini-audio-service
ssh admin@47.79.254.213 'bash -s' < 服务器诊断并修复.sh
```

脚本会：检查进程、端口、本地 API、日志 → **自动重启服务** → 再次验证。

### 方式二：手动 SSH 操作

```bash
# 1. 连接服务器
ssh admin@47.79.254.213

# 2. 进入项目目录
cd ~/gemini-audio-service

# 3. 检查后端是否运行
pgrep -af main.py

# 4. 若无输出，说明已停止。重启：
pkill -f "python.*main" 2>/dev/null
sleep 3
nohup venv/bin/python3 main.py >> ~/gemini-audio-service.log 2>&1 &

# 5. 等待 15 秒后，本地测试 API
sleep 15
curl -X POST "http://127.0.0.1:8000/api/v1/auth/send-code" -H "Content-Type: application/json" -d '{"phone":"13800138000"}'
# 应返回 JSON，含 code:200

# 6. 查看崩溃原因（若频繁宕机）
tail -100 ~/gemini-audio-service.log
```

### 方式三：阿里云控制台

若 SSH 无法连接：
1. 登录阿里云 ECS 控制台
2. 找到实例 47.79.254.213，使用 **网页终端/VNC**
3. 执行上述第 2–6 步

---

## 长期方案：systemd 守护进程

配置 systemd 后，进程崩溃会自动重启。创建 `/etc/systemd/system/gemini-audio.service`：

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

启用：`sudo systemctl enable gemini-audio && sudo systemctl start gemini-audio`
