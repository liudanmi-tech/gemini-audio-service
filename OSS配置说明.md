# OSS 配置说明

## 环境变量配置

在 `.env` 文件中添加以下配置：

```bash
# OSS 配置
SS_ACCESS_KEY_ID=your_access_key_id
OSS_ACCESS_KEY_SECRET=your_access_key_secret
OSS_ENDPOINT=Ooss-cn-hangzhou.aliyuncs.com  # 根据你的 OSS 区域修改
OSS_BUCKET_NAME=your-bucket-name
OSS_CDN_DOMAIN=your-cdn-domain.com  # 可选，如果使用 CDN

# 是否启用 OSS（默认 true）
USE_OSS=true
```

## 配置说明

### 1. OSS_ACCESS_KEY_ID 和 OSS_ACCESS_KEY_SECRET
- 从阿里云控制台获取
- 路径：阿里云控制台 → AccessKey 管理 → 创建 AccessKey

### 2. OSS_ENDPOINT
- 根据你的 OSS Bucket 所在区域选择
- 常见区域：
  - 华东1（杭州）: `oss-cn-hangzhou.aliyuncs.com`
  - 华东2（上海）: `oss-cn-shanghai.aliyuncs.com`
  - 华北1（青岛）: `oss-cn-qingdao.aliyuncs.com`
  - 华北2（北京）: `oss-cn-beijing.aliyuncs.com`
  - 华南1（深圳）: `oss-cn-shenzhen.aliyuncs.com`

### 3. OSS_BUCKET_NAME
- 你的 OSS Bucket 名称
- 需要在阿里云 OSS 控制台创建

### 4. OSS_CDN_DOMAIN（可选）
- 如果配置了 CDN，填写 CDN 域名
- 如果不配置，将使用 OSS 直接访问 URL

## OSS Bucket 配置

### 1. 创建 Bucket
1. 登录阿里云 OSS 控制台
2. 创建 Bucket
3. 选择区域（建议选择与服务器相同的区域）
4. 存储类型选择：标准存储
5. 读写权限：私有（推荐）或公共读

### 2. 配置 CORS（如果需要）
如果客户端需要直接访问 OSS，需要配置 CORS：

```json
{
  "AllowedOrigins": ["*"],
  "AllowedMethods": ["GET", "HEAD"],
  "AllowedHeaders": ["*"],
  "ExposeHeaders": [],
  "MaxAgeSeconds": 3600
}
```

### 3. 配置生命周期规则（可选）
在 OSS 控制台配置生命周期规则，自动删除过期文件：

1. 进入 Bucket → 生命周期
2. 创建规则：
   - 规则名称：清理图片
   - 前缀：`images/`
   - 过期天数：7 天（或根据需求）
   - 操作：删除

## 功能说明

### 1. 图片上传
- 图片生成后自动上传到 OSS
- 文件路径：`images/{session_id}/{image_index}.png`
- 如果 OSS 上传失败，自动降级到 Base64

### 2. 图片访问
- URL 格式：
  - OSS 直接访问: `https://{bucket}.{endpoint}/images/{session_id}/{index}.png`
  - CDN 访问: `https://{cdn_domain}/images/{session_id}/{index}.png`
  - 通过 API 访问: `GET /api/v1/images/{session_id}/{image_index}`

### 3. 访问控制
- 图片访问接口会验证 session_id 是否存在
- 只有有效的 session_id 才能访问图片

### 4. 文件清理
- 提供清理接口：`GET /api/v1/admin/cleanup-images?days=7`
- 可以手动调用清理过期文件
- 建议配置 OSS 生命周期规则自动清理

## 测试步骤

### 1. 安装依赖
```bash
pip install oss2>=2.18.0
```

### 2. 配置环境变量
在 `.env` 文件中添加 OSS 配置

### 3. 重启服务
```bash
pkill -f 'python.*main.py'
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
```

### 4. 测试图片生成
调用策略分析接口，检查返回的 `image_url` 字段

### 5. 测试图片访问
```bash
curl "http://localhost:8001/api/v1/images/{session_id}/0"
```

### 6. 测试清理功能
```bash
curl "http://localhost:8001/api/v1/admin/cleanup-images?days=7"
```

## 故障排查

### 问题 1: OSS 上传失败
- 检查 AccessKey 是否正确
- 检查 Endpoint 是否正确
- 检查 Bucket 名称是否正确
- 检查网络连接

### 问题 2: 图片访问 404
- 检查文件是否已上传
- 检查 session_id 是否正确
- 检查 OSS 权限配置

### 问题 3: 图片访问 503
- 检查 OSS 是否启用
- 检查 oss_bucket 是否初始化成功
- 查看日志了解详细错误

## 性能优化建议

1. **使用 CDN**：
   - 配置 CDN 域名加速图片访问
   - 设置合适的缓存策略

2. **图片压缩**（可选）：
   - 在上传前压缩图片
   - 减少存储和传输成本

3. **异步上传**（可选）：
   - 图片生成后立即返回
   - 后台异步上传到 OSS

4. **生命周期管理**：
   - 配置 OSS 生命周期规则
   - 自动清理过期文件
