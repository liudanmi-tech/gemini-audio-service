# 音频分析微服务 - 技术方案文档

## 1. 系统架构

### 1.1 整体架构
```
客户端 → FastAPI 服务 (本地:8001) → 反向代理服务器 (阿里云:47.79.254.213) → Google Gemini API
```

### 1.2 技术栈
- **后端框架**: FastAPI 0.104.1+
- **Python 版本**: 3.14
- **AI 模型**: Google Gemini 3 Flash Preview
- **代理服务器**: 阿里云新加坡服务器 (Ubuntu 24.04)
- **反向代理**: Nginx 1.24.0
- **依赖管理**: pip + requirements.txt

## 2. 核心功能

### 2.1 API 接口
- **POST /analyze-audio**: 音频分析接口
  - 输入: 音频文件 (mp3/wav/m4a)
  - 输出: JSON 格式的分析结果
  
- **GET /health**: 健康检查接口
- **GET /test-gemini**: Gemini API 连接测试接口
- **GET /docs**: Swagger UI 文档

### 2.2 音频分析功能
1. **说话人识别**: 识别音频中的说话人数量
2. **对话提取**: 按时间顺序提取所有对话内容
3. **语气分析**: 分析每个说话人的语气（平静、愤怒、轻松等）
4. **风险识别**: 识别对话中的关键风险点

### 2.3 返回数据格式
```json
{
  "speaker_count": 2,
  "dialogues": [
    {
      "speaker": "说话人1",
      "content": "具体说话内容",
      "tone": "语气"
    }
  ],
  "risks": ["风险点1", "风险点2"]
}
```

## 3. 反向代理配置

### 3.1 服务器信息
- **公网 IP**: 47.79.254.213
- **地区**: 新加坡
- **操作系统**: Ubuntu 24.04.2 LTS
- **Web 服务器**: Nginx 1.24.0

### 3.2 Nginx 配置
**配置文件位置**: `/etc/nginx/sites-available/default`

**关键配置**:
```nginx
# /secret-channel 路径反向代理
location /secret-channel {
    rewrite ^/secret-channel(.*) $1 break;
    proxy_pass https://generativelanguage.googleapis.com;
    proxy_set_header Host generativelanguage.googleapis.com;
    proxy_ssl_server_name on;
    proxy_ssl_verify off;
    client_max_body_size 100M;
    proxy_read_timeout 600s;
}

# /upload 路径反向代理（用于文件上传）
location /upload {
    proxy_pass https://generativelanguage.googleapis.com;
    proxy_set_header Host generativelanguage.googleapis.com;
    proxy_ssl_server_name on;
    proxy_ssl_verify off;
    client_max_body_size 100M;
    proxy_read_timeout 600s;
}
```

### 3.3 为什么需要两个 location 块？
- `/secret-channel`: 用于常规 API 请求
- `/upload`: 用于 Google API 返回的 resumable upload Location 头中的路径

## 4. 代码实现细节

### 4.1 URL 重写机制
使用 Monkey Patch 方式修改 `googleapiclient.http.HttpRequest.execute` 方法：
- 检测包含 `generativelanguage.googleapis.com` 的 URL
- 将 URL 替换为代理服务器地址 + `/secret-channel` 前缀
- 例如: `https://generativelanguage.googleapis.com/v1beta/...` 
  → `http://47.79.254.213/secret-channel/v1beta/...`

### 4.2 文件上传流程
1. 接收上传的音频文件
2. 保存到临时文件
3. 调用 `genai.upload_file()` 上传到 Gemini
4. 等待文件状态变为 ACTIVE
5. 调用模型分析音频
6. 解析返回的 JSON
7. 清理临时文件和 Gemini 上的文件

### 4.3 错误处理
- 文件上传重试机制（最多 3 次）
- 模型调用重试机制（最多 3 次）
- 详细的日志记录
- 完整的错误堆栈跟踪

## 5. 环境配置

### 5.1 环境变量 (.env)
```
GEMINI_API_KEY=your_api_key_here
PROXY_URL=http://47.79.254.213/secret-channel
USE_PROXY=true
```

### 5.2 依赖包 (requirements.txt)
```
fastapi>=0.104.1
uvicorn[standard]>=0.24.0
google-generativeai>=0.3.2
python-multipart>=0.0.6
pydantic>=2.9.0
python-dotenv>=1.0.0
aiofiles>=23.2.1
```

## 6. 模型选择

### 6.1 当前使用模型
- **模型名称**: `gemini-3-flash-preview`
- **选择原因**: 免费层有配额，速度快，支持音频分析

### 6.2 模型限制
- `gemini-3-pro-preview`: 免费层配额为 0，需要付费计划
- `gemini-3-flash-preview`: 免费层有配额，适合使用

## 7. 日志系统

### 7.1 日志输出位置
- **标准输出**: 终端输出
- **服务日志**: `/tmp/gemini-service.log`
- **详细日志**: `/tmp/gemini-audio-service.log`

### 7.2 日志级别
- **INFO**: 正常流程信息
- **DEBUG**: 详细调试信息
- **ERROR**: 错误信息和堆栈跟踪

## 8. 部署说明

### 8.1 本地服务启动
```bash
cd /Users/liudan/Desktop/AI军师/gemini-audio-service
python3 main.py
```

### 8.2 服务访问
- **API 文档**: http://localhost:8001/docs
- **健康检查**: http://localhost:8001/health
- **API 接口**: http://localhost:8001/analyze-audio

### 8.3 服务器配置
- Nginx 配置已部署在阿里云服务器
- 反向代理已配置并测试通过
- 防火墙已开放 80 端口

## 9. 关键问题解决

### 9.1 代理配置问题
- **问题**: `google-generativeai` SDK 不支持直接设置自定义 base URL
- **解决**: 使用 Monkey Patch 修改 HTTP 请求的 URL

### 9.2 文件上传路径问题
- **问题**: Google API 返回的 Location 头不包含 `/secret-channel` 前缀
- **解决**: 在 Nginx 中同时配置 `/upload` 路径的反向代理

### 9.3 模型配额问题
- **问题**: `gemini-3-pro-preview` 免费层配额为 0
- **解决**: 改用 `gemini-3-flash-preview`，免费层有配额

## 10. 性能指标

- **文件上传时间**: 约 5-10 秒（取决于文件大小）
- **文件处理时间**: 约 2-5 秒
- **模型分析时间**: 约 5-10 秒
- **总处理时间**: 约 15-25 秒（0.7MB 音频文件）

## 11. 安全考虑

1. **API Key 管理**: 使用 `.env` 文件，不提交到代码仓库
2. **文件清理**: 自动清理临时文件和 Gemini 上的文件
3. **错误处理**: 不暴露敏感信息给客户端
4. **代理验证**: SSL 验证已关闭（仅用于开发环境）

## 12. 后续优化建议

1. 添加请求限流机制
2. 支持更多音频格式
3. 添加缓存机制（相同文件不重复分析）
4. 支持批量文件处理
5. 添加 WebSocket 支持实时进度反馈


