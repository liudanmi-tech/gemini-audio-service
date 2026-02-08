# API 接口与端口说明

## 端口说明（重要）

- **应用只监听一个端口**：技能、档案、列表、详情、档案识别匹配等**所有功能**都在**同一个进程、同一个端口**上。
- **当前默认端口**：`main.py` 中为 **8000**（可通过环境变量 `UVICORN_PORT` 改为 8001）。
- **与 Nginx 的关系**：客户端访问 `http://47.79.254.213/api/v1/...`（对外是 80 端口），Nginx 将 `/api/` 反向代理到本机 **8000**（若你曾把 Nginx 配成 8001，则需与当前应用端口一致）。
- **结论**：档案识别匹配、技能、档案、详情、列表都走 **8000**（或你配置的 8001），没有“档案用 8000、技能用 8001”这种按功能分端口；端口一致即可。

**端口分配与避免占用**：80 仅 Nginx 监听，8000（或 8001）仅 FastAPI 应用监听；避免同一应用重复启动导致「端口被占用」。详见 **`避免端口占用说明.md`**，重启建议用 **`安全重启应用.sh`**。

---

## 功能与接口对照表

**监听端口**：所有接口由同一应用进程监听，默认 **8000**，可通过环境变量 `UVICORN_PORT` 改为 **8001**；Nginx 对外 80，反向代理到该端口。

| 功能 | 监听端口 | 方法 | 接口路径 | 说明 |
|------|----------|------|----------|------|
| **认证** | | | | |
| 发送验证码 | 8000 / 8001 | POST | `/api/v1/auth/send-code` | |
| 登录 | 8000 / 8001 | POST | `/api/v1/auth/login` | |
| 当前用户信息 | 8000 / 8001 | GET | `/api/v1/auth/me` | |
| **技能** | | | | |
| 技能列表 | 8000 / 8001 | GET | `/api/v1/skills` | 可带 `?enabled=1`、`?category=workplace` 等 |
| 技能详情 | 8000 / 8001 | GET | `/api/v1/skills/{skill_id}` | |
| 技能重载 | 8000 / 8001 | POST | `/api/v1/skills/{skill_id}/reload` | |
| **档案** | | | | |
| 档案列表 | 8000 / 8001 | GET | `/api/v1/profiles` | 当前用户的档案列表 |
| 创建档案 | 8000 / 8001 | POST | `/api/v1/profiles` | |
| 更新档案 | 8000 / 8001 | PUT | `/api/v1/profiles/{profile_id}` | |
| 删除档案 | 8000 / 8001 | DELETE | `/api/v1/profiles/{profile_id}` | |
| 上传档案照片 | 8000 / 8001 | POST | `/api/v1/profiles/upload-photo` | |
| **任务/会话（列表与详情）** | | | | |
| 任务/会话列表 | 8000 / 8001 | GET | `/api/v1/tasks/sessions` | 支持 `?page=1&page_size=20` |
| 任务/会话详情 | 8000 / 8001 | GET | `/api/v1/tasks/sessions/{session_id}` | 详情页数据 |
| 任务状态 | 8000 / 8001 | GET | `/api/v1/tasks/sessions/{session_id}/status` | 分析状态轮询 |
| **策略与场景** | | | | |
| 策略分析（Call#2） | 8000 / 8001 | POST | `/api/v1/tasks/sessions/{session_id}/strategies` | 生成策略与视觉 |
| 场景分类 | 8000 / 8001 | POST | `/api/v1/tasks/sessions/{session_id}/classify-scene` | 场景识别 |
| **录音与片段** | | | | |
| 录音上传 | 8000 / 8001 | POST | `/api/v1/audio/upload` | 上传并触发分析 |
| 音频片段列表 | 8000 / 8001 | GET | `/api/v1/tasks/sessions/{session_id}/audio-segments` | |
| 提取片段 | 8000 / 8001 | POST | `/api/v1/tasks/sessions/{session_id}/extract-segment` | |
| **其他** | | | | |
| 策略图片 | 8000 / 8001 | GET | `/api/v1/images/{session_id}/{image_index}` | 策略生成的图片 |
| 健康检查 | 8000 / 8001 | GET | `/health` | 不含 /api 前缀 |

---

## 客户端访问方式

- **Base URL**：`http://47.79.254.213/api/v1`（走 80 端口，由 Nginx 转发）。
- 上述所有接口的完整 URL = Base URL + 路径，例如：
  - 技能列表：`GET http://47.79.254.213/api/v1/skills?enabled=1`
  - 档案列表：`GET http://47.79.254.213/api/v1/profiles`
  - 任务列表：`GET http://47.79.254.213/api/v1/tasks/sessions`
  - 任务详情：`GET http://47.79.254.213/api/v1/tasks/sessions/{session_id}`

档案识别匹配、技能、档案、详情、列表都通过上述同一 Base URL 访问，**不区分 8000 或 8001**；只要服务端应用监听端口与 Nginx `proxy_pass` 一致（建议 8000）即可。
