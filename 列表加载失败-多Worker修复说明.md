# 列表/ auth 加载失败 - 多 Worker 修复说明

## 现象

- 任务列表、auth/me 请求超时（120 秒无响应）
- 日志显示「响应时间: 120.xxx 秒」「响应数据为空」

## 根因

**单 worker 阻塞**：uvicorn 默认只有 1 个 worker。当有长耗时请求（OSS 下载大文件、策略生成、Gemini 调用）时，该 worker 被占满，**其它请求（列表、auth）只能排队等待**，直到超时。

## 修复步骤

通过 **阿里云控制台 → ECS 实例 → 远程连接** 登录服务器，复制执行 `阿里云远程连接-复制执行-修正版.txt` 中的**整段命令**。脚本会：

1. **重启应用并启用 4 个 worker**：`--workers 4`
   - 长任务和列表/auth 可在不同 worker 并行处理
2. **将 Nginx 超时改为 600s**：避免策略、上传等长请求被中间切断

## 验证

执行后在服务器上运行：

```bash
# 确认有 4 个 worker 进程
ps aux | grep uvicorn | grep -v grep

# 快速测试列表接口（约 1–3 秒应返回）
curl -s -m 10 "http://127.0.0.1:8000/api/v1/tasks/sessions?page=1&page_size=5" \
  -H "Authorization: Bearer YOUR_TOKEN" | head -c 200
```

列表在 10 秒内返回即表示修复生效。客户端重新加载任务列表即可。
