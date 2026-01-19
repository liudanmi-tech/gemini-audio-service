# Git 提交指南

## 问题
无法连接到 GitHub (Failed to connect to github.com port 443)

## 解决方案

### 方案1: 切换到 SSH 方式（推荐）

```bash
# 1. 切换到 SSH 方式
git remote set-url origin git@github.com:liudanmi-tech/gemini-audio-service.git

# 2. 测试 SSH 连接
ssh -T git@github.com

# 3. 如果 SSH 密钥未配置，需要先配置
# 查看是否有 SSH 密钥
ls -la ~/.ssh/id_rsa*

# 如果没有，生成新的 SSH 密钥
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# 将公钥添加到 GitHub
cat ~/.ssh/id_rsa.pub
# 然后复制内容到 GitHub Settings > SSH and GPG keys > New SSH key
```

### 方案2: 配置代理（如果使用代理）

```bash
# 配置 HTTP 代理
git config --global http.proxy http://proxy.example.com:8080
git config --global https.proxy http://proxy.example.com:8080

# 取消代理配置
git config --global --unset http.proxy
git config --global --unset https.proxy
```

### 方案3: 使用脚本自动处理

```bash
# 切换到 SSH 并提交
chmod +x 切换到SSH并提交.sh
bash 切换到SSH并提交.sh

# 或配置代理并提交
chmod +x 配置代理并提交.sh
bash 配置代理并提交.sh
```

## 手动提交步骤

### 1. 检查状态
```bash
git status
```

### 2. 添加更改
```bash
git add .
```

### 3. 提交更改
```bash
git commit -m "feat: 增强v0.4技能架构日志输出，显示匹配的技能ID和名称

- 增强技能匹配日志，显示具体匹配到的技能ID和名称
- 增强策略分析生成日志，显示应用的技能详情
- 增强技能执行日志，显示技能名称
- 创建技能信息查看脚本和文档"
```

### 4. 推送到 GitHub
```bash
# 如果使用 SSH
git push origin main

# 如果使用 HTTPS（需要配置代理或使用 VPN）
git push origin main
```

## 检查远程仓库配置

```bash
# 查看远程仓库 URL
git remote -v

# 如果是 HTTPS，切换到 SSH
git remote set-url origin git@github.com:liudanmi-tech/gemini-audio-service.git
```

## 常见问题

### 1. SSH 密钥未添加到 GitHub
- 访问 https://github.com/settings/keys
- 点击 "New SSH key"
- 粘贴 `~/.ssh/id_rsa.pub` 的内容

### 2. 网络连接问题
- 检查网络连接
- 尝试使用 VPN
- 检查防火墙设置

### 3. 代理配置错误
- 确认代理地址和端口正确
- 检查代理是否需要认证
