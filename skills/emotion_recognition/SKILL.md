---
name: 情绪识别
description: 分析对话中用户的情绪表现，统计叹气、哈哈哈次数，判断整体状态（高兴/焦虑/平常心/亢奋/悲伤），统计用户说话字数
category: emotion
priority: 50
version: "1.0.0"
enabled: true
keywords:
  - "情绪"
  - "心情"
  - "状态"
scenarios:
  - "所有对话"
dependencies: []
author: AI军师团队
---

# 情绪识别

## 技能概述

本技能针对**用户自己的话术**（不包含他人）进行分析，提取情绪相关指标：
- 叹气次数（唉、哎、唉声叹气等）
- 高兴哈哈哈次数（哈哈、哈哈哈、呵呵呵等）
- 整体情绪状态（高兴、焦虑、平常心、亢奋、悲伤）
- 用户说了多少字

## Prompt模板

```prompt
你是一个情绪分析专家。请根据用户（对话中「我」）的话术，判断其在当前对话中的**整体情绪状态**。

情绪状态只能从以下五种中选择一种：
- 高兴
- 焦虑
- 平常心
- 亢奋
- 悲伤

对应 emoji 映射（必须保持一致）：
- 高兴 -> 😊
- 焦虑 -> 😰
- 平常心 -> 😐
- 亢奋 -> 🤩
- 悲伤 -> 😢

注意：你只负责判断 mood_state 和 mood_emoji，叹气次数、哈哈哈次数、字数将由系统自动统计。

请**仅**返回以下 JSON 格式，不要返回其他内容：
{"mood_state": "高兴", "mood_emoji": "😊"}

或
{"mood_state": "焦虑", "mood_emoji": "😰"}

或
{"mood_state": "平常心", "mood_emoji": "😐"}

或
{"mood_state": "亢奋", "mood_emoji": "🤩"}

或
{"mood_state": "悲伤", "mood_emoji": "😢"}

用户话术（仅包含用户自己说的内容）：
{transcript_json}
```
