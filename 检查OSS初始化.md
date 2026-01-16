# 检查 OSS 初始化

## 扩大搜索范围

如果最近的日志中没有 OSS 信息，尝试查看更多的日志：

```bash
# 查看最近 200 行日志
tail -200 ~/gemini-audio-service.log | grep -E "OSS|oss2|配置"

# 或者查看服务启动时的日志
grep -E "OSS|oss2|配置成功|初始化" ~/gemini-audio-service.log | tail -20

# 查看完整的启动日志
tail -100 ~/gemini-audio-service.log
```

## 直接测试 OSS 功能

如果日志中没有 OSS 信息，可以直接测试功能：

### 方法 1: 测试 OSS 连接

```bash
python3 -c "
import os
from dotenv import load_dotenv
load_dotenv()

try:
    import oss2
    auth = oss2.Auth(
        os.getenv('OSS_ACCESS_KEY_ID'),
        os.getenv('OSS_ACCESS_KEY_SECRET')
    )
    bucket = oss2.Bucket(auth, os.getenv('OSS_ENDPOINT'), os.getenv('OSS_BUCKET_NAME'))
    
    # 测试列出文件（空列表也正常）
    result = bucket.list_objects(max_keys=1)
    print('✅ OSS 连接成功！')
    print(f'Bucket: {os.getenv(\"OSS_BUCKET_NAME\")}')
    print(f'Endpoint: {os.getenv(\"OSS_ENDPOINT\")}')
except Exception as e:
    print(f'❌ OSS 连接失败: {e}')
    import traceback
    traceback.print_exc()
"
```

### 方法 2: 测试图片生成和上传

使用一个 session_id 调用策略分析接口，查看是否能成功上传图片到 OSS。

## 检查代码是否正确加载配置

```bash
python3 -c "
import sys
sys.path.insert(0, '/home/admin/gemini-audio-service')
from main import USE_OSS, oss_bucket, OSS_ENDPOINT, OSS_BUCKET_NAME

print('USE_OSS:', USE_OSS)
print('oss_bucket:', '已初始化' if oss_bucket else '未初始化')
print('OSS_ENDPOINT:', OSS_ENDPOINT)
print('OSS_BUCKET_NAME:', OSS_BUCKET_NAME)
"
```
