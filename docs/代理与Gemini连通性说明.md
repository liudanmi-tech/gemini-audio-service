# 代理与 Gemini 连通性说明

## 错误 "string indices must be integers, not 'str'"

该错误出现在**上传文件到 Gemini** 阶段（不是 Gemini 分析接口本身的问题）。

**含义**：SDK 期望收到 JSON，实际收到了**字符串**（通常是 HTML 错误页），并对它做了 `resp["key"]` 这类操作，导致报错。

**常见原因**：Nginx 把请求转发到 `generativelanguage.googleapis.com` 时**失败**（超时、连接被拒等），于是返回 **502 Bad Gateway** 的 HTML 页面；SDK 把这个 HTML 当 JSON 解析/当字典访问，就出现上述错误。

**根本原因**：**当前服务器无法直接访问 Google**（例如服务器在中国大陆，直连 generativelanguage.googleapis.com 会被阻断或超时）。

---

## 解决思路

1. **确认服务器能否访问 Google**  
   在服务器上执行：
   ```bash
   curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://generativelanguage.googleapis.com
   ```
   - 若返回 `000` 或超时：说明本机无法直连 Google，需要下面 2 或 3。
   - 若返回 `4xx`/`5xx`：说明能连上，可能是 API Key 或路径问题。

2. **使用能访问 Google 的机器部署**  
   将应用部署到能直连 Google 的服务器（例如海外区域），并正确配置 Nginx 代理与 API Key。

3. **让 Nginx 通过“上游代理”访问 Google**  
   若必须用当前服务器，需要有一台**能访问 Google 的代理**（如海外代理或带 VPN 的机器），然后：
   - 在该代理上暴露一个 HTTP 代理（或直接转发到 `https://generativelanguage.googleapis.com`），
   - 在当前服务器的 Nginx 里，把 `proxy_pass` 指向该代理（或该代理转发的 Gemini 地址），  
   这样“当前服务器 → 代理 → Google”的链路才能通。

4. **API Key 与路径**  
   若服务器本身能访问 Google，再检查：
   - `.env` 里 `GEMINI_API_KEY` 正确，
   - Nginx 的 `/secret-channel/` 转发路径与 SDK 使用的路径一致（如 `/$discovery/rest`、`/upload/v1beta/files` 等）。

---

## 小结

- **"string indices must be integers"**：多半是**代理/上游返回了 HTML（如 502）**，不是 Gemini 接口设计问题。
- **502 常见原因**：当前服务器**访问不到** `generativelanguage.googleapis.com`（如在中国大陆）。
- **可行方案**：换能访问 Google 的服务器部署，或在当前服务器上通过“能访问 Google 的上游代理”再连 Gemini。
