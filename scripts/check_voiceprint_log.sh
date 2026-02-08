#!/usr/bin/env bash
# 3.1 在服务器上确认是否因剪切失败导致无人匹配：在日志中搜索声纹/剪切/失败/ffmpeg 等
# 用法: ./scripts/check_voiceprint_log.sh [session_id] [log_path]
# 示例: ./scripts/check_voiceprint_log.sh 1dda0515-14d3-4f55-a9b3-f3affcd57e27 ~/gemini-audio-service.log

SESSION_ID="${1:-1dda0515-14d3-4f55-a9b3-f3affcd57e27}"
LOG_PATH="${2:-$HOME/gemini-audio-service.log}"

if [[ ! -f "$LOG_PATH" ]]; then
  echo "Log file not found: $LOG_PATH"
  exit 1
fi

echo "=== session_id=$SESSION_ID log=$LOG_PATH ==="
echo "--- [声纹] / 开始剪切 / 声纹匹配失败 ---"
grep -E "session_id=$SESSION_ID|声纹|开始剪切|声纹匹配失败" "$LOG_PATH" || true
echo "--- cut_audio / pydub / ffmpeg 相关错误 ---"
grep -iE "cut_audio_segment|pydub|ffmpeg|AudioSegment|decode" "$LOG_PATH" | tail -50 || true
