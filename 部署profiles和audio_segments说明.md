# 部署 profiles 和 audio_segments API 到服务器

## 问题
服务器返回 404 错误，说明路由 `/api/v1/profiles` 不存在。需要将更新后的代码部署到服务器。

## 需要上传的文件
1. `api/profiles.py` - 路由前缀已更新为 `/api/v1/profiles`
2. `api/audio_segments.py` - 路由前缀已更新为 `/api/v1/tasks/sessions`

## 部署步骤

### 方法 1: 使用 scp 命令（推荐）

在终端执行以下命令：

```bash
# 1. 上传 api/profiles.py
scp api/profiles.py admin@47.79.254.213:~/gemini-audio-service/api/

# 2. 上传 api/audio_segments.py
scp api/audio_segments.py admin@47.79.254.213:~/gemini-audio-service/api/

# 3. SSH 到服务器并重启服务
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service
source venv/bin/activate

# 停止旧服务
pkill -f "python.*main.py" || echo "没有运行中的服务"
sleep 2

# 启动新服务
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &

# 等待服务启动
sleep 5

# 检查服务是否运行
if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动"
    echo ""
    echo "查看最新日志:"
    tail -30 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|profiles|ERROR"
else
    echo "❌ 服务启动失败"
    echo "查看错误日志:"
    tail -50 ~/gemini-audio-service.log
fi

# 测试路由
echo ""
echo "测试路由（应该返回 401 或 403，不是 404）:"
curl -s http://localhost:8001/api/v1/profiles -H "Authorization: Bearer test" 2>&1 | head -5
EOF
```

### 方法 2: 使用部署脚本

如果 SSH 配置正确，可以直接运行：

```bash
./上传profiles和audio_segments到服务器.sh
```

## 验证部署

部署成功后，应该能够：
1. 创建档案不再返回 404
2. 获取档案列表正常工作
3. 更新和删除档案正常工作

## 如果仍然失败

1. 检查服务器日志：`ssh admin@47.79.254.213 'tail -50 ~/gemini-audio-service.log'`
2. 检查路由是否注册：在服务器上运行 `python3 -c "from api.profiles import router; print(router.prefix)"`
3. 检查服务是否运行：`ssh admin@47.79.254.213 'ps aux | grep python'`
