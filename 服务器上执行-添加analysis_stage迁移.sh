#!/bin/bash
# 在服务器上执行：添加 sessions.analysis_stage 列
# 用于分析进度可见性（客户端可展示「正在上传到云端」「正在分析对话」等）
set -e
cd ~/gemini-audio-service
echo "执行 analysis_stage 迁移..."
psql "$DATABASE_URL" -f database/migrations/add_session_analysis_stage.sql || \
  (echo "若使用其他方式连接数据库，请手动执行:"; cat database/migrations/add_session_analysis_stage.sql)
echo "完成。重启服务以生效: systemctl --user restart gemini-audio 或 pkill -f uvicorn && cd ~/gemini-audio-service && nohup uvicorn ... &"
