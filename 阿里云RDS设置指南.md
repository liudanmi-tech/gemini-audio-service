# 阿里云RDS PostgreSQL设置指南

## 一、创建RDS实例

### 1. 登录阿里云控制台
访问：https://ecs.console.aliyun.com/

### 2. 进入RDS管理页面
- 在左侧菜单找到"云数据库RDS"
- 或直接访问：https://rdsnext.console.aliyun.com/

### 3. 创建PostgreSQL实例
1. 点击"创建实例"
2. 选择配置：
   - **数据库类型**：PostgreSQL
   - **版本**：PostgreSQL 14或更高版本（推荐14）
   - **地域**：选择与应用服务器相同的地域（如：华东1-杭州）
   - **可用区**：选择与应用服务器相同的可用区（降低延迟）
   - **实例规格**：
     - 开发/测试：`pg.n2.medium.1`（1核2GB，约¥200/月）
     - 生产环境：`pg.n2.large.1`（2核4GB，约¥400/月）或更高
   - **存储空间**：20GB起步（根据数据量调整）
   - **存储类型**：SSD云盘（推荐）

### 4. 设置网络和账号
- **网络类型**：专有网络VPC（推荐）
- **VPC**：选择与应用服务器相同的VPC
- **交换机**：选择与应用服务器相同的交换机
- **数据库账号**：设置主账号（如：`gemini_admin`）
- **数据库密码**：设置强密码（至少8位，包含大小写字母、数字、特殊字符）

### 5. 完成创建
- 点击"立即购买"或"创建实例"
- 等待5-10分钟，实例创建完成

## 二、配置RDS实例

### 1. 设置白名单
1. 进入RDS实例详情页
2. 点击"数据安全性" → "白名单设置"
3. 添加应用服务器的IP地址：
   - 方式1：添加ECS内网IP（推荐，更安全）
   - 方式2：添加 `0.0.0.0/0`（允许所有IP，仅用于测试，生产环境不推荐）

### 2. 创建数据库
1. 进入RDS实例详情页
2. 点击"数据库管理" → "创建数据库"
3. 设置：
   - **数据库名称**：`gemini_audio_db`
   - **字符集**：UTF8
   - **授权账号**：选择刚才创建的主账号
   - **账号权限**：读写

### 3. 获取连接信息
在RDS实例详情页的"基本信息"中，找到：
- **连接地址**：`rm-xxxxx.pg.rds.aliyuncs.com`（内网地址，推荐）
- **端口**：`5432`（PostgreSQL默认端口）
- **数据库名**：`gemini_audio_db`
- **账号**：`gemini_admin`（你创建的主账号）

## 三、配置应用服务器

### 1. 更新环境变量

在应用服务器的 `.env` 文件中更新数据库连接URL：

```env
# 数据库配置（使用RDS内网地址）
DATABASE_URL=postgresql+asyncpg://gemini_admin:your_password@rm-xxxxx.pg.rds.aliyuncs.com:5432/gemini_audio_db
```

**重要说明**：
- 使用**内网地址**（`rm-xxxxx.pg.rds.aliyuncs.com`），不要使用外网地址
- 内网地址访问免费且速度更快
- 如果应用服务器和RDS不在同一VPC，需要配置VPC互通或使用外网地址

### 2. 测试连接

在应用服务器上测试数据库连接：

```bash
# 安装PostgreSQL客户端（如果还没有）
sudo apt install postgresql-client

# 测试连接
psql -h rm-xxxxx.pg.rds.aliyuncs.com -U gemini_admin -d gemini_audio_db

# 输入密码后，如果看到 psql 提示符，说明连接成功
```

### 3. 初始化数据库表

```bash
# 方式1：使用SQL脚本
psql -h rm-xxxxx.pg.rds.aliyuncs.com -U gemini_admin -d gemini_audio_db -f database/migrations/init_tables.sql

# 方式2：使用Python脚本（需要先配置好环境变量）
python3 database/migrations/init_db.py
```

## 四、安全配置（重要）

### 1. 修改默认端口（可选）
- RDS默认使用5432端口
- 可以在RDS控制台修改端口号，提高安全性

### 2. 启用SSL连接（推荐）
1. 在RDS控制台 → "数据安全性" → "SSL"
2. 下载SSL证书
3. 在应用代码中配置SSL连接（如果需要）

### 3. 定期备份
1. 在RDS控制台 → "备份恢复"
2. 设置自动备份策略：
   - **备份周期**：每天
   - **备份时间**：选择业务低峰期（如：凌晨2点）
   - **保留天数**：7-30天（根据需求）

### 4. 监控和告警
1. 在RDS控制台 → "监控与报警"
2. 设置关键指标告警：
   - CPU使用率 > 80%
   - 内存使用率 > 80%
   - 磁盘使用率 > 80%
   - 连接数 > 80%

## 五、成本优化建议

### 1. 选择合适的规格
- **开发/测试环境**：使用最低配置（1核2GB）
- **生产环境**：根据实际负载选择，可以从小规格开始，按需升级

### 2. 使用包年包月（可选）
- 包年包月比按量付费便宜约15-30%
- 适合长期使用的项目

### 3. 存储空间优化
- 定期清理过期数据
- 使用数据归档策略
- 监控存储使用情况，及时扩容

## 六、故障排查

### 1. 连接失败
**问题**：`could not connect to server`

**解决方案**：
- 检查白名单是否包含应用服务器IP
- 检查VPC网络是否互通
- 检查安全组规则是否允许5432端口
- 尝试使用外网地址（如果内网不通）

### 2. 认证失败
**问题**：`password authentication failed`

**解决方案**：
- 检查数据库账号和密码是否正确
- 检查账号是否有访问该数据库的权限
- 在RDS控制台重置密码

### 3. 数据库不存在
**问题**：`database "gemini_audio_db" does not exist`

**解决方案**：
- 在RDS控制台创建数据库
- 检查数据库名称是否正确

## 七、迁移现有数据（如果有）

如果之前使用的是内存存储，需要重新上传音频文件，因为：
1. 内存数据无法直接迁移到数据库
2. 新的架构需要用户登录后才能创建任务
3. 建议在迁移期间保持旧版本运行，新用户使用新版本

## 八、验证部署

### 1. 检查数据库连接
```bash
# 在应用服务器上
python3 -c "
import asyncio
from database.connection import engine
from sqlalchemy import text

async def test():
    async with engine.connect() as conn:
        result = await conn.execute(text('SELECT version()'))
        print('✅ 数据库连接成功')
        print(result.scalar())

asyncio.run(test())
"
```

### 2. 检查表结构
```bash
psql -h rm-xxxxx.pg.rds.aliyuncs.com -U gemini_admin -d gemini_audio_db -c "\dt"
```

应该看到5个表：
- users
- sessions
- analysis_results
- strategy_analysis
- verification_codes

### 3. 测试API接口
```bash
# 1. 发送验证码
curl -X POST "http://your-server-ip:8001/api/v1/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000"}'

# 2. 登录
curl -X POST "http://your-server-ip:8001/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000", "code": "123456"}'

# 3. 使用Token访问接口
TOKEN="your_token_here"
curl -X GET "http://your-server-ip:8001/api/v1/tasks/sessions" \
  -H "Authorization: Bearer $TOKEN"
```

## 九、常见问题FAQ

### Q1: RDS和ECS在同一VPC，为什么连接不上？
A: 检查：
1. RDS白名单是否包含ECS内网IP
2. ECS安全组是否允许出站5432端口
3. RDS安全组是否允许入站5432端口

### Q2: 可以使用外网地址吗？
A: 可以，但不推荐：
- 外网地址需要开启"外网地址"功能
- 外网访问会产生流量费用
- 安全性较低
- 延迟较高

### Q3: 如何查看RDS的连接数？
A: 在RDS控制台 → "监控与报警" → "连接数"图表

### Q4: RDS实例可以降配吗？
A: 可以，但有限制：
- 需要先释放部分存储空间
- 降配可能需要重启实例
- 建议在业务低峰期操作

### Q5: 如何备份和恢复数据？
A: 
- **自动备份**：RDS自动每天备份，保留7-30天
- **手动备份**：在RDS控制台创建手动备份
- **恢复**：在RDS控制台选择备份点进行恢复

## 十、下一步

完成RDS配置后：
1. 更新应用服务器的 `.env` 文件
2. 初始化数据库表
3. 重启应用服务
4. 测试认证和API接口
5. 配置监控和告警
