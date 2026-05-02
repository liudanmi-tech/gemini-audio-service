# 图片生成完整逻辑

> 最后更新：2026-04-21
> 涉及文件：`main.py`、`scene_image_generator.py`、`RecordingViewModel.swift`

---

## 一、整体流程

```
用户上传音频
      │
      ▼
analyze_audio_async()
      │
      ├─ Step 1：Gemini 转录音频 → transcript（带 is_me / speaker 标签）
      │
      ├─ Step 2：声纹匹配 → 写入 AnalysisResult.speaker_mapping
      │           单说话人 + 单档案 → 直接映射
      │           多说话人 → 仅映射 is_me 说话人到"自己"档案
      │           无档案 / 无音频 → speaker_mapping 为空
      │
      ├─ Step 3：asyncio.create_task(generate_scene_images(...))  ← 场景图【并行启动】
      │
      └─ Step 4：await _generate_strategies_core(...)            ← 技能分析【并行执行】
```

---

## 二、图片类型

| 类型 | 数量 | index 范围 | 生成入口 |
|------|------|-----------|---------|
| 技能配图（Skill Images） | 每个技能 1 张 | 0, 1, 2 … | `_generate_strategies_core()` |
| 场景还原图（Scene Images） | 1～5 张 | 1000, 1001 … | `generate_scene_images()` |

---

## 三、场景图生成：`generate_scene_images()`

> `scene_image_generator.py`

```
generate_scene_images(transcript, style_key, session_id, user_id, ...)
      │
      ├─ [1] sessions.image_status = "generating"
      │
      ├─ [2] 构建带角色标签对话文本（最多 80 行）
      │       [我]   = is_me=True  → 画面左侧
      │       [对方] = is_me=False → 画面右侧
      │
      ├─ [3] Gemini Flash 分析场景（1～5 个）
      │       要求：明确"谁"做"什么"，不能颠倒动作主体
      │       返回：{"scenes": ["场景1", ...]}
      │
      ├─ [4] 加载档案参考图 → _get_profile_reference_images()
      │       （见第四章，三级兜底策略）
      │
      ├─ [4.5] profile_refs 为空时 → 人物档案文字分析（30s 超时）
      │         _analyze_character_profiles() → consistency_header
      │         超时则跳过，直接生成（不注入人物描述）
      │
      ├─ [5] asyncio.gather 并行生成所有图片
      │       每张最多等 120s，超时返回 None（视为失败跳过）
      │       → generate_image_from_prompt()（见第五章）
      │
      ├─ [6] 组装 scene_images 列表
      │       [{index, scene_description, image_url, image_base64}, ...]
      │
      ├─ [7] 写入 strategy_analysis.scene_images
      │       若 StrategyAnalysis 未创建：暂存到 sessions.analysis_stage_detail
      │       兜底重试：每 10s 查一次，最多等 5 分钟（30 次）
      │
      └─ [8] sessions.image_status = "completed" / "failed"
```

### 场景识别 Prompt 规则

- 对话用 `[我]` / `[对方]` 标签标注
- 每个场景必须明确动作主体（"用户"或"对方"），不得颠倒
- 示例：`"用户正在向对方汇报工作进展，对方表情严肃地听取"`

---

## 四、档案参考图加载：`_get_profile_reference_images()`

> `main.py`，三级兜底策略

### 策略优先级

```
_get_profile_reference_images(session_id, user_id, db)
      │
      ├─ [Level 1] 从 AnalysisResult.speaker_mapping 查声纹匹配档案
      │             relationship_type == "自己"  → left_pid（用户，左侧）
      │             relationship_type != "自己"  → right_pid（对方，右侧）
      │             兜底：无"自己"时取第一个有效档案作 left_pid
      │
      ├─ [Level 2] left_pid 仍为空
      │             → Profile WHERE relationship_type="自己"
      │               AND photo_url IS NOT NULL
      │             （直接查用户自己档案，不依赖声纹）
      │
      ├─ [Level 3] right_pid 仍为空
      │             → Profile WHERE audio_session_id=session_id
      │               AND relationship_type != "自己"
      │               AND photo_url IS NOT NULL
      │             （从本次对话音频创建的对方档案）
      │
      └─ 照片加载（left_pid 和 right_pid 各取一张）
              优先：OSS 直读 images/{user_id}/profile_{pid}/0.png
              兜底：photo_url 直链 HTTP（仅非 /api/v1/images/ 格式）
              返回：[(bytes, mime)]，左侧在前，右侧在后，最多 2 张
```

### 何时没有参考图？

| 情况 | 原因 |
|------|------|
| 用户没有任何档案 | 三级均查不到 |
| 档案没有"自己"关系类型 | Level 2 查不到 |
| 对方档案未从本次会话创建 | Level 3 查不到 |
| 档案存在但没有头像 | photo_url IS NULL，条件过滤掉 |
| OSS 读取失败 | 照片加载步骤失败，该位置跳过 |

**参考图无法加载时**：自动进入文字级人物一致性（consistency_header）

---

## 五、人物档案文字分析：`_analyze_character_profiles()`

> `scene_image_generator.py`，仅在 profile_refs 为空时调用

```
输入：transcript 前 20 句（用户 / 对方各取）
      │
      ▼
Gemini Flash（30s 超时）
推断双方：gender / age_range / role / appearance
      │
      ▼
consistency_header 拼接：
"左侧为{user.appearance}（用户），右侧为{other.appearance}（对方）。"
      │
      ▼
注入所有场景 prompt 开头（文字级人物一致性）
```

超时后 consistency_header = ""，跳过注入，直接生成。

---

## 六、单张图片生成：`generate_image_from_prompt()`

> `main.py`

### 模型

```
gemini-3.1-flash-image-preview（Nano Banana 2）
支持多模态输入：文字 + 图片（风格参考图 + 档案参考图）
```

### Contents 组装顺序

```
contents_list = [
  风格参考图（可选）      ← style_references/{style_key}_ref.jpg（本地）
  左侧人物参考图（可选）  ← 用户档案照片 bytes
  右侧人物参考图（可选）  ← 对方档案照片 bytes
  full_prompt（文字）
]
```

### Prompt 拼接结构

```
full_prompt =
  [风格参考图说明]（有风格参考图时）
  + 风格前缀（IMAGE_STYLE_MAP[style_key]）
  + position_rule（每张图固定注入）
  + ref_desc（有档案参考图时）
  + prompt_body（场景描述，无参考图时开头含 consistency_header）
```

**position_rule（固定，每张必带）：**
> 「【重要】画面中左侧人物固定为用户，右侧人物固定为对方。必须严格按照场景描述中的动作主体来绘制：谁做动作就画谁在做，不能颠倒角色。」

### 有 / 无档案参考图对比

| | 有参考图 | 无参考图 |
|--|--------|---------|
| 人物一致性 | 图片级（传入照片） | 文字级（consistency_header） |
| ref_desc | "第一张图为左侧（用户）参考照片，…请保持面部与气质一致" | 无 |
| prompt_body 开头 | 纯场景描述 | `{consistency_header}{场景描述}` |

### 输出与重试

```
生成结果（bytes）
      ├─ OSS 已启用 → 上传 images/{user_id}/{session_id}/{image_index}.png
      │               返回 OSS CDN URL
      └─ OSS 未启用 → base64 编码返回

重试：默认 3 次
  429 限流：提取 retryDelay，至少等 15s 再重试
  其他异常：立即重试
```

### 风格列表

| 大类 | style_key |
|------|-----------|
| 动画 | `ghibli` `shinkai` `pixar` `toriyama` `clamp` |
| 漫画 | `noir_manga` `jojo` `retro_manga` `line_art` |
| 艺术 | `watercolor` `oil_painting` `chinese_ink` `rembrandt` |
| 现代 | `cyberpunk` `pixel` `pop_art` `constructivism` |
| 手工 | `clay` `felt` `scandinavian` `storybook` |
| 其他 | `ukiyoe` `steampunk` |

风格参考图路径：`style_references/{style_key}_ref.jpg`（存在则自动加载）

---

## 七、iOS 轮询逻辑：`pollForImages()`

> `RecordingViewModel.swift`

```
策略分析完成后启动图片轮询
      │
      ├─ 每 3 秒查一次 GET /api/v1/sessions/{id}/image-status
      ├─ 最多查 60 次（180 秒）
      ├─ status="completed" AND totalScenes>0
      │     → 拉取最新详情 + 预缓存策略分析 + 预加载第一张图
      │     → 发送 TaskAnalysisCompleted 通知（卡片变可点击）
      └─ 超时兜底（180s 后）
            → 以基础详情发送通知（无封面）
            → 用户进入详情页后触发自动刷新
```

---

## 八、数据库字段

| 表 | 字段 | 说明 |
|----|------|------|
| `sessions` | `image_status` | `pending` / `generating` / `completed` / `failed` |
| `sessions` | `analysis_stage_detail` | scene_images 暂存（StrategyAnalysis 未就绪时） |
| `strategy_analysis` | `scene_images` | JSONB 数组，最终存储 |
| `analysis_results` | `speaker_mapping` | `{"Speaker_0": "profile_uuid", ...}` |
| `profiles` | `relationship_type` | `"自己"` / `"领导"` / `"同事"` 等 |
| `profiles` | `photo_url` | 头像 API URL |
| `profiles` | `audio_session_id` | 从哪个 session 音频创建的档案 |

---

## 九、超时保护一览

| 位置 | 超时 | 超时后行为 |
|------|------|----------|
| `_analyze_character_profiles` | 30s | 跳过，consistency_header="" |
| 单张图片生成（`gen_one`） | 120s | 返回 None，该图标记失败 |
| iOS 图片轮询（`pollForImages`） | 180s（60×3s）| 兜底通知，进详情页后自动刷新 |
| 技能图生成（继承 Gemini 超时） | 无单独设置 | — |

---

## 十、常见问题排查

| 现象 | 可能原因 | 排查日志关键词 |
|------|---------|--------------|
| 图片卡在 generating | 人物分析/图片生成 API 挂死（已有超时保护） | `[场景生图] 超时` |
| 没有使用参考图 | 档案缺"自己"类型 / 无 photo_url / OSS 失败 | `[档案照片]` |
| 参考图 OSS 读取失败 | 档案未上传头像 / OSS 配置问题 | `[档案照片] 无法加载` |
| 人物动作颠倒 | 场景描述动作主体不明确 | `[场景生图] 提取到 N 个场景` |
| 多张图人物不一致 | 无参考图 + 人物分析超时 | `[场景生图] 人物档案分析超时` |
| scene_images 迟迟不写入 | StrategyAnalysis 超时未创建 | `[场景生图] 兜底重试超时` |
| iOS 60s 超时（旧问题） | maxWaits=20 → 已改为 60 | — |
