#!/usr/bin/env bash
# 在服务器上执行：根据任务ID(session_id) 查服务端日志与 DB，排查「未挂档案」问题。
# 用法: ./scripts/check_task_voiceprint_logs.sh b861478d-d868-4e01-b682-d5fb0b407145
# 或:   TASK_ID=b861478d-d868-4e01-b682-d5fb0b407145 ./scripts/check_task_voiceprint_logs.sh

set -e
TASK_ID="${1:-$TASK_ID}"
if [ -z "$TASK_ID" ]; then
  echo "用法: $0 <session_id/任务ID>"
  echo "  或: TASK_ID=<session_id> $0"
  exit 1
fi

echo "========== 任务声纹/档案诊断 session_id=$TASK_ID =========="
echo ""

# 1) 服务端日志：声纹相关
LOG_FILES=(
  "$HOME/gemini-audio-service.log"
  "/home/admin/gemini-audio-service.log"
  "./gemini-audio-service.log"
)
FOUND_LOG=""
for f in "${LOG_FILES[@]}"; do
  if [ -f "$f" ]; then
    FOUND_LOG="$f"
    break
  fi
done
if [ -n "$FOUND_LOG" ]; then
  echo "=== 1. 服务端日志（声纹相关） 文件=$FOUND_LOG ==="
  grep -E "(\[声纹\]|声纹匹配|identify_speaker|speaker_mapping).*$TASK_ID|$TASK_ID.*(\[声纹\]|声纹匹配|speaker_mapping)" "$FOUND_LOG" 2>/dev/null || true
  echo ""
  echo "--- 该任务全部相关日志（最近 50 条）---"
  grep "$TASK_ID" "$FOUND_LOG" 2>/dev/null | tail -50 || true
else
  echo "=== 1. 未找到日志文件（请在本项目目录或 admin 用户下执行）==="
  echo "可手动执行: grep \"$TASK_ID\" ~/gemini-audio-service.log"
  echo "            grep \"[声纹]\" ~/gemini-audio-service.log | grep \"$TASK_ID\""
fi
echo ""

# 2) 数据库：check_speaker_mapping.py
echo "=== 2. 数据库：Session / AnalysisResult / speaker_mapping ==="
if [ -f "check_speaker_mapping.py" ]; then
  python3 check_speaker_mapping.py "$TASK_ID" 2>/dev/null || true
else
  echo "未找到 check_speaker_mapping.py，请在本项目根目录执行。"
  echo "或: python3 /path/to/gemini-audio-service/check_speaker_mapping.py $TASK_ID"
fi
echo ""
echo "========== 诊断结束 =========="
echo ""
echo "常见原因："
echo "  - 日志出现「无原音频 URL/路径」→ 原音频未持久化(OSS/本地)，检查 persist_original_audio 与 OSS 配置"
echo "  - 日志出现「无法获取本地音频」→ 服务器无法下载 OSS 或本地路径不可读"
echo "  - 日志出现「当前用户无档案」→ 该 user 下没有档案，需先创建档案"
echo "  - 日志出现「speaker_mapping 已写入」但界面仍显示「用户」→ 总结文案里 Gemini 用了「用户」而非 Speaker_0，替换逻辑只替换 Speaker_0/Speaker_1"
