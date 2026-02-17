# RDS 登录修复 - 完整步骤

按顺序执行以下步骤，解决 iOS 登录失败（数据库连接被拒）问题。

## 一、阿里云 RDS 控制台操作

### 1. 添加白名单（必须）
1. 登录 [RDS 控制台](https://rdsnext.console.aliyun.com/)
2. 选择 PostgreSQL 实例 `pgm-2ze5w19pz5t064k04o`
3. 左侧 **数据安全性** → **白名单设置**
4. 点击 **修改** 或 **添加**，添加 IP：`47.79.254.213`（应用服务器公网 IP）
5. 保存

### 2. 处理 SSL 与 CA 证书（若报 "rejected SSL upgrade"）
1. 左侧 **数据安全性** → **SSL**
2. 若 SSL 已启用（常见）：
   - 选择「使用云端证书」
   - 点击 **下载 CA 证书**
   - 解压得到 PEM 文件（如 `ApsaraDB-CA-Chain.pem`）
   - 保存到本地，例如：`./certs/rds-ca.pem`

## 二、本地执行修复脚本

在项目目录下执行（根据你是否有 CA 证书选择其一）：

### 方式 A：有 CA 证书（推荐，适用于 RDS 已开启 SSL）
```bash
# 确保已将 connection.py 和 certs 放在正确位置
# 使用本地 CA 证书，脚本会自动上传
LOCAL_CA_CERT=./certs/rds-ca.pem DATABASE_SSL=true ./修复RDS登录问题.sh
```

### 方式 B：无 CA 证书，仅启用 SSL 加密
```bash
# 若 RDS 未强制 verify-ca，可能可以连接
DATABASE_SSL=true ./修复RDS登录问题.sh
```

### 方式 C：RDS 未开启 SSL（少见）
```bash
DATABASE_SSL=false ./修复RDS登录问题.sh
```

## 三、验证

- 脚本执行后应看到「✅ 登录接口正常」
- 或在服务器测试：
  ```bash
  curl -s -X POST "http://47.79.254.213/api/v1/auth/send-code" \
    -H "Content-Type: application/json" -d '{"phone":"13800138000"}'
  curl -s -X POST "http://47.79.254.213/api/v1/auth/login" \
    -H "Content-Type: application/json" -d '{"phone":"13800138000","code":"123456"}'
  ```
- 返回含 `"token"` 即成功，再在 iOS 中尝试登录

## 四、常见错误与处理

| 错误 | 处理 |
|------|------|
| `no encryption` | 设置 `DATABASE_SSL=true` |
| `rejected SSL upgrade` | 下载 RDS CA 证书，用方式 A 执行 |
| `could not connect` | 检查白名单是否已添加 47.79.254.213 |
| SSH 连接失败 | 检查 `DEPLOY_SERVER`，默认 `admin@47.79.254.213` |
