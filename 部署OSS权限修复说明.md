# 部署OSS权限修复说明

## 问题

图片加载失败，返回HTTP 403错误。这是因为OSS Bucket权限为私有，不允许匿名访问。

## 解决方案

已在`main.py`中添加了ACL设置，上传图片时自动设置为`public-read`。

## 部署步骤

### 1. 上传修复后的代码

```bash
scp main.py admin@47.79.254.213:~/gemini-audio-service/
```

### 2. 验证代码已更新

```bash
ssh admin@47.79.254.213 'grep -A 3 "x-oss-object-acl" ~/gemini-audio-service/main.py'
```

应该看到：
```python
'x-oss-object-acl': 'public-read'  # 设置对象为公共读
```

### 3. 重启服务

```bash
ssh admin@47.79.254.213
cd ~/gemini-audio-service
pkill -f "python3 main.py"
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
tail -f ~/gemini-audio-service.log
```

### 4. 验证服务启动

查看日志，应该看到：
- `✅ OSS 配置成功`
- 服务正常启动

## 验证修复

部署后，请：
1. 在客户端重新上传一张新图片
2. 新上传的图片应该可以正常访问（不再返回403）
3. 旧的图片仍然会返回403（需要在OSS控制台手动修改权限，或重新上传）

## 注意事项

- 新上传的图片会自动设置为公共读
- 旧的图片需要重新上传或手动修改权限
- 如果仍有问题，检查OSS Bucket的权限设置
