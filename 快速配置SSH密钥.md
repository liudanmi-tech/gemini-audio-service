# 快速配置 SSH 密钥指南

## 当前状态
- ✅ 代码已提交到本地仓库 (commit 9bd82c4)
- ❌ 推送到 GitHub 失败：SSH 密钥未配置

## 解决步骤

### 方式1: 使用自动脚本（推荐）

```bash
bash 配置SSH密钥并推送.sh
```

### 方式2: 手动配置

#### 步骤1: 检查是否有 SSH 密钥

```bash
ls -la ~/.ssh/id_rsa*
```

#### 步骤2A: 如果有密钥，查看公钥

```bash
cat ~/.ssh/id_rsa.pub
```

复制输出的内容，然后：
1. 访问 https://github.com/settings/keys
2. 点击 "New SSH key"
3. 粘贴公钥内容
4. 点击 "Add SSH key"

#### 步骤2B: 如果没有密钥，生成新的

```bash
# 生成 SSH 密钥（替换为您的邮箱）
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# 按 Enter 使用默认路径
# 可以设置密码或直接按 Enter 跳过

# 查看公钥
cat ~/.ssh/id_rsa.pub
```

然后按照步骤2A将公钥添加到 GitHub。

#### 步骤3: 测试 SSH 连接

```bash
ssh -T git@github.com
```

如果看到 "Hi username! You've successfully authenticated..." 说明配置成功。

#### 步骤4: 推送到 GitHub

```bash
git push origin main
```

## 常见问题

### 1. Permission denied (publickey)
- 检查 SSH 公钥是否已添加到 GitHub
- 检查 SSH 密钥文件权限：`chmod 600 ~/.ssh/id_rsa`

### 2. 多个 SSH 密钥
如果使用多个 GitHub 账户，需要配置 SSH config：
```bash
# 编辑 ~/.ssh/config
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_rsa
```

### 3. SSH 代理
如果使用 SSH 代理：
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
```

## 验证配置

```bash
# 测试连接
ssh -T git@github.com

# 查看远程仓库配置
git remote -v
# 应该显示: git@github.com:liudanmi-tech/gemini-audio-service.git
```
