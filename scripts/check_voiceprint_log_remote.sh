#!/usr/bin/env bash
# 在本地执行，通过 SSH 在服务器上查看指定 session 的声纹相关日志（用于排查两人对话未匹配档案）
# 用法: ./scripts/check_voiceprint_log_remote.sh [session_id] [ssh_host]
# 示例: ./scripts/check_voiceprint_log_remote.sh ae025ad1-c91c-4b6d-8419-58cba8f6c4d6

SESSION_ID="${1:-ae025ad1-c91c-4b6d-8419-58cba8f6c4d6}"
SSH_HOST="${2:-admin@47.79.254.213}"
# 日志路径在服务器上展开（用单引号传参避免本地展开 ~）
LOG='~/gemini-audio-service.log'

echo "========== 声纹日志排查（远程） =========="
echo "Session ID: $SESSION_ID"
echo "SSH: $SSH_HOST"
echo ""

echo "--- 该 session 下所有 [声纹] 相关日志 ---"
ssh "$SSH_HOST" 'S='"$SESSION_ID"' L='"$LOG"'; grep "$S" $L 2>/dev/null | grep 声纹' || echo "未找到或命令失败"
echo ""

echo "--- 剪切/匹配/降级/写入结果 ---"
ssh "$SSH_HOST" 'S='"$SESSION_ID"' L='"$LOG"'; grep "$S" $L 2>/dev/null | grep -E "开始剪切|剪切成功|声纹匹配失败|降级占位|speaker_mapping 已写入|speaker_mapping 为空"' || echo "未找到或命令失败"
echo ""

echo "--- 最近 cut_audio/pydub/ffmpeg 相关错误（全日志 tail） ---"
ssh "$SSH_HOST" 'grep -iE "cut_audio_segment|pydub|ffmpeg|AudioSegment|decode" '"$LOG"' 2>/dev/null | tail -30' || echo "未找到或命令失败"
