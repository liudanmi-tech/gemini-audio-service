# 轮询状态失败（HTTP 0）诊断

## 现象
```
❌ [RecordingViewModel] 轮询状态失败:
   - 错误信息: 请求失败 (HTTP 0) / 连接超时，请检查网络后重试
```

- **HTTP 0**：未收到任何 HTTP 响应
- **连接超时**：请求在 30 秒内未得到响应（status 接口已改为 30s 超时，超时后会每 3 秒重试）

---

## 常见原因与处理

### 1. 网络不可达
- **模拟器**：模拟器与宿主机共享网络，需确保 Mac 能访问 `47.79.254.213`
- **真机**：手机需连网（Wi‑Fi/蜂窝），且能访问该 IP

**验证**：在 Mac 终端执行
```bash
curl -v --connect-timeout 5 "http://47.79.254.213/api/v1/auth/send-code" -X POST -H "Content-Type: application/json" -d '{"phone":"13800138000"}'
```
- 能返回 JSON → 网络可达
- `Connection timed out` 或 `Connection refused` → 网络/防火墙问题

### 2. App Transport Security (ATS)
- 使用 HTTP 时，需在 Info.plist 配置 `NSExceptionAllowsInsecureHTTPLoads`
- 确认已为 `47.79.254.213` 或对应域名添加例外

### 3. 服务器短暂不可用
- 轮询会每 3 秒重试，偶发 HTTP 0 可忽略
- 若持续失败，检查服务器与 Nginx 是否正常

### 4. 服务器负载高
- 若正在分析录音，后端可能忙于 Gemini 调用，响应变慢
- 轮询会继续重试，分析完成后通常可恢复

### 5. Token 过期或无效
- 状态接口需要 JWT，Token 无效会返回 401（有 HTTP 响应，不是 0）
- HTTP 0 / 超时 一般与 Token 无关，多属网络或服务可用性

---

## 代码改动

已在 `NetworkManager.getTaskStatus` 中增强错误处理：
- **HTTP 0** 时根据底层错误类型显示更明确提示（超时、网络不可达、无法连接等）
- 方便区分是超时、断网还是服务器不可达

---

## 建议排查步骤

1. 确认 Mac/手机能访问 `http://47.79.254.213`
2. 在 Safari 或浏览器打开 `http://47.79.254.213`，看能否访问
3. 若用模拟器，确认 Mac 网络正常
4. 若用真机，确认手机与服务器网络互通（同一 Wi‑Fi 或可访问公网）
5. 查看 Xcode 控制台完整错误，确认是否包含 `timed out`、`offline`、`host` 等关键词
