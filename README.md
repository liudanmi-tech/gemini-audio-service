# 音频分析微服务

基于 FastAPI 和 Google Gemini 3 API 的音频分析服务，支持识别说话人、提取对话内容、分析语气和风险点。

## 核心功能

- ✅ 识别音频中的说话人数量
- ✅ 按时间顺序提取所有对话内容
- ✅ 分析每个说话人的语气（平静、愤怒、轻松等）
- ✅ 识别关键风险点
- ✅ 支持 mp3/wav/m4a 格式
- ✅ 通过反向代理访问 Google API（适合国内环境）

## 快速开始

### 1. 安装依赖

```bash
pip3 install -r requirements.txt
```

### 2. 配置环境变量

创建 `.env` 文件：

```
GEMINI_API_KEY=your_api_key_here
PROXY_URL=http://47.79.254.213/secret-channel
USE_PROXY=true
```

### 3. 启动服务

```bash
python3 main.py
```

服务将在 `http://localhost:8001` 启动。

### 4. 使用 API

**接口地址**: `POST /analyze-audio`

**请求**: 上传音频文件（mp3/wav/m4a）

**响应**: JSON 格式的分析结果

```json
{
  "speaker_count": 2,
  "dialogues": [
    {
      "speaker": "说话人1",
      "content": "具体说话内容",
      "tone": "轻松"
    },
    {
      "speaker": "说话人2",
      "content": "具体说话内容",
      "tone": "平静"
    }
  ],
  "risks": ["风险点1", "风险点2"]
}
```

## API 文档

启动服务后，访问以下地址查看自动生成的 API 文档：

- Swagger UI: `http://localhost:8001/docs`
- ReDoc: `http://localhost:8001/redoc`
- 健康检查: `http://localhost:8001/health`

## 技术架构

- **后端框架**: FastAPI
- **AI 模型**: Google Gemini 3 Flash Preview
- **反向代理**: 阿里云新加坡服务器 + Nginx
- **详细技术方案**: 查看 [TECHNICAL_DESIGN.md](./TECHNICAL_DESIGN.md)

## 日志查看

实时查看详细日志：

```bash
tail -f /tmp/gemini-audio-service.log
```

