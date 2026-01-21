# SSH 连接问题排查指南

## 当前问题
SSH 连接测试失败，无法推送到 GitHub

## 排查步骤

### 1. 确认公钥已添加到 GitHub

**重要**: 请确认公钥已正确添加到 GitHub：

1. 访问: https://github.com/settings/keys
2. 检查是否有您的 SSH 公钥
3. 如果没有，点击 "New SSH key" 添加：
   - Title: `MacBook Pro` (或任意名称)
   - Key: 粘贴完整的公钥内容（从 `ssh-rsa` 开始到邮箱结束）
   - 点击 "Add SSH key"

**公钥内容**（完整复制）：
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCoBi44uE+5DckiM6chjGwoYptNSnmrr3P3hfRFc+xDoHwl3FWoYDsJ1+IcZLJadI1qzpr3aoytKxFjhocppMfJfW2MrLsKtQNR9ZxjT/Dq7U6snsuarbHd44wyDrHm+O7k0506pZEeYmFFDnaCmI6JSZ2WEJ5X9NzHqmSGZ63stILwEYmrI3YctanFZGpl/5Md2ppykZG1J9NIiUXtof7DOKzBgU0bWDoHLlMOSZ6yRl9nG76i3UndNjD5KoKNxfKR8sJVKEgskj3DSgeb/PbQZzlpowNxak8rp+qm03Sl2g7aLdPZqtIysntmL9gYBWQ1QwgJ/tc4xFzIYELykhqYZh46X0hMij2qlcPDlIhtMh6xLaK0AQ0uak6d95fCr8oOHVJDdCn+pJnR0zpXhMFF1n6C64ZoSknAqK3iQVm3NtmtBCDg0f7x1411BI/R2JW5aawWdVEmDAnU+g8NuarCk3QiMexV6+F4J7nBjLTbgxyk0AzuOKtnGYLLL+sJIb6ZMYism3YfWXPhX0OXARAmc8fuoJOsPcmX9yQLIkLbPOzk6/7iVNvQR3vBNGZnWRT1WN7sH4GQDAYVKjfIiBWsdELOg9cLkilUtN63sa/L0YE4Xwm6TKGYeVjwFF5bQigAblL1GwO80pYvrYDJGG/vgvq8LZfMkR2AF8Sshe2XmQ== liudan@liudandeMacBook-Pro.local
```

### 2. 使用诊断脚本

```bash
bash 诊断并修复SSH.sh
```

这个脚本会：
- 检查 SSH 密钥文件
- 设置正确的文件权限
- 启动 ssh-agent 并添加密钥
- 测试 SSH 连接
- 如果成功，自动推送代码

### 3. 手动排查

#### 步骤1: 检查文件权限

```bash
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

#### 步骤2: 启动 ssh-agent 并添加密钥

```bash
# 启动 ssh-agent
eval "$(ssh-agent -s)"

# 添加密钥
ssh-add ~/.ssh/id_rsa

# 验证密钥已添加
ssh-add -l
```

#### 步骤3: 测试连接（详细模式）

```bash
ssh -vT git@github.com
```

查看输出中的关键信息：
- `Authentications that can continue: publickey` - 说明支持公钥认证
- `Offering public key` - 说明正在尝试使用公钥
- `successfully authenticated` - 说明认证成功

#### 步骤4: 如果仍然失败，检查 SSH 配置

```bash
# 创建或编辑 SSH 配置
cat >> ~/.ssh/config << EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
```

### 4. 常见问题

#### 问题1: Permission denied (publickey)

**原因**: 公钥未添加到 GitHub 或公钥内容不完整

**解决**:
1. 确认公钥已添加到 GitHub
2. 确认公钥内容完整（从 `ssh-rsa` 开始到邮箱结束）
3. 检查是否有额外的空格或换行

#### 问题2: 网络连接问题

**原因**: 无法连接到 GitHub

**解决**:
1. 检查网络连接
2. 如果使用 VPN，确保 VPN 正常工作
3. 尝试使用代理（如果网络环境需要）

#### 问题3: 多个 SSH 密钥

**原因**: 系统中有多个 SSH 密钥，GitHub 使用了错误的密钥

**解决**: 在 `~/.ssh/config` 中明确指定使用哪个密钥

### 5. 验证配置

```bash
# 测试连接
ssh -T git@github.com

# 如果看到 "Hi username! You've successfully authenticated..." 说明成功
```

### 6. 推送代码

连接成功后，推送代码：

```bash
git push origin main
```

## 备用方案：使用 HTTPS + Personal Access Token

如果 SSH 仍然无法工作，可以切换回 HTTPS 并使用 Personal Access Token：

```bash
# 切换到 HTTPS
git remote set-url origin https://github.com/liudanmi-tech/gemini-audio-service.git

# 推送时使用 Personal Access Token 作为密码
git push origin main
# 用户名: 您的 GitHub 用户名
# 密码: Personal Access Token (不是 GitHub 密码)
```

生成 Personal Access Token:
1. 访问: https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 选择权限: `repo`
4. 生成并复制 token
5. 推送时使用 token 作为密码
