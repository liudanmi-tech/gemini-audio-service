#!/bin/bash
# 在阿里云 Workbench 中执行：诊断「录音上传成功但轮询失败」
# 将输出复制给开发者分析

LOG="$HOME/gemini-audio-service.log"

echo "========== 1. 最近上传的 session（含 session_id）=========="
grep -E "\[upload\]|session_id|sessionId|收到音频" "$LOG" 2>/dev/null | tail -30

echo ""
echo "========== 2. 异步分析流程（开始→各阶段→完成/失败）=========="
grep -E "开始异步分析音频|oss_upload|gemini_analysis|voiceprint|Session 已更新原音频|文件上传处理开始|尝试上传|文件上传成功|文件处理完成|分析音频失败|数据库Session已更新|archived|failed" "$LOG" 2>/dev/null | tail -80

echo ""
echo "========== 3. 错误与异常 =========="
grep -E "ERROR|TypeError|Exception|上传失败|分析音频失败|Traceback" "$LOG" 2>/dev/null | tail -40

echo ""
echo "========== 4. 最近 50 行原始日志 =========="
tail -50 "$LOG"
