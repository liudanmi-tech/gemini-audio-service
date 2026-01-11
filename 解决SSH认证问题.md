# 解决 SSH 认证问题

## 问题
SSH 连接需要密码，但认证失败。可能的原因：
1. 密码输入错误
2. 服务器配置了只允许公钥认证
3. 需要使用 SSH 密钥

## 解决方案

### 方案 1: 配置 SSH 密钥（推荐）

#### 在 Mac 终端执行：

```bash
# 1. 检查是否已有 SSH 密钥
ls -la ~/.ssh/id_rsa.pub

# 2. 如果没有，生成 SSH 密钥
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# 按 Enter 使用默认路径，可以设置密码或留空

# 3. 复制公钥到服务器
ssh-copy-id admin@47.79.254.213
# 输入服务器密码

# 4. 测试连接（应该不需要密码了）
ssh admin@47.79.254.213
```

### 方案 2: 手动上传文件（如果 SSH 密钥配置有问题）

#### 在 Mac 终端执行：

```bash
cd ~/Desktop/AI军师/gemini-audio-service

# 使用 scp 上传（会提示输入密码）
scp main.py admin@47.79.254.213:~/gemini-audio-service/
scp requirements.txt admin@47.79.254.213:~/gemini-audio-service/
scp .env admin@47.79.254.213:~/gemini-audio-service/
```

每次都会提示输入密码，确保密码正确。

### 方案 3: 在服务器上直接创建文件

如果上传有问题，可以在服务器上直接创建文件。

#### 在服务器上执行（SSH 连接后）：

```bash
# 创建项目目录
mkdir -p ~/gemini-audio-service
cd ~/gemini-audio-service

# 创建 main.py（需要复制内容）
nano main.py
# 粘贴 main.py 的内容，然后 Ctrl+X, Y, Enter 保存

# 创建 requirements.txt
nano requirements.txt
# 粘贴 requirements.txt 的内容

# 创建 .env
nano .env
# 粘贴 .env 的内容
```

## 快速检查

### 在 Mac 终端测试连接：

```bash
# 测试 SSH 连接
ssh admin@47.79.254.213

# 如果连接成功，说明认证没问题
# 如果失败，需要配置 SSH 密钥或确认密码
```

## 推荐流程

1. **先配置 SSH 密钥**（方案 1），这样以后就不需要每次输入密码
2. **然后重新执行上传脚本**
3. **或者在服务器上手动创建文件**（方案 3）


