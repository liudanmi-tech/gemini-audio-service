# Gemini 文件上传：中国服务器说明

## 问题现象
- 轮询一直停在「正在分析对话…」，分析永远不完成
- 服务端日志：`尝试上传 resumable=False` 之后无后续

## 根因

### GEMINI_FILE_UPLOAD_NO_PROXY=true 导致挂起
阿里云 ECS 在中国，**无法直连** `generativelanguage.googleapis.com`。设置 `GEMINI_FILE_UPLOAD_NO_PROXY=true` 后，文件上传会尝试直连 Google，连接会一直挂起，直到超时。

### 代理模式 TypeError
使用代理（`/secret-channel`）时，若代理返回 502 或异常响应，SDK 会抛出 `TypeError: string indices must be integers`。

---

## 解决方案

### 1. 立即修复：关闭 NO_PROXY

在服务器 `.env` 中**删除或注释**该行：
```bash
# 删除或注释
# GEMINI_FILE_UPLOAD_NO_PROXY=true
```

然后重启服务。这样会恢复使用代理，至少不会无限挂起。

### 2. 已添加 90 秒超时
- `genai.upload_file` 现带 90 秒超时（可设 `GEMINI_UPLOAD_TIMEOUT=120` 调整）
- 超时后会抛出异常，分析任务会标记为 `failed`，客户端可停止轮询

### 3. 代理可用性
若代理仍有 TypeError，需检查：
- Nginx `/secret-channel` 是否正确转发到 Gemini API
- 代理上游是否可达、是否返回正确 JSON

### 4. 长期方案（若代理不可用）
- 使用海外服务器部署（可直连 Google）
- 或在阿里云 ECS 上配置 VPN/专线访问 Google
