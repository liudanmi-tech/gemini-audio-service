# 更新API密钥指南

## 问题
API密钥被标记为泄漏，需要更换新的密钥。

## 解决步骤

### 1. 生成新的API密钥
访问：https://aistudio.google.com/app/apikey
创建新的API密钥并复制

### 2. 在服务器上更新密钥

```bash
# SSH连接到服务器
ssh admin@47.79.254.213

# 进入项目目录
cd /home/admin/gemini-audio-service

# 备份旧的.env文件
cp .env .env.backup

# 编辑.env文件
nano .env

# 或者使用vi
vi .env
```

在.env文件中，将：
```
GEMINI_API_KEY=AIzaSyCiOOgxgMkTuqw6sXTT08WbD7R6kMK-k08
```

替换为新的API密钥：
```
GEMINI_API_KEY=你的新API密钥
```

保存并退出（nano: Ctrl+X, Y, Enter; vi: Esc, :wq, Enter）

### 3. 重启服务

```bash
# 停止当前服务
ps aux | grep "python.*main.py" | grep -v grep
# 记录进程ID，然后：
kill <进程ID>

# 或者
pkill -f "python.*main.py"

# 激活虚拟环境
source venv/bin/activate

# 重新启动服务
nohup python3 main.py > ~/gemini-service.log 2>&1 &

# 等待几秒
sleep 3

# 检查服务状态
ps aux | grep "python.*main.py" | grep -v grep
curl http://localhost:8001/health

# 查看日志确认
tail -n 20 ~/gemini-service.log
```

### 4. 验证
测试上传功能，应该可以正常工作了。

## 注意事项

1. **不要将API密钥提交到代码仓库**
2. **不要在文档中公开API密钥**
3. **使用.env文件存储敏感信息**
4. **确保.env文件在.gitignore中**
