#!/bin/bash

# 调试 image_prompt 输出

echo "========== 查看最近的策略分析日志 =========="
ssh admin@47.79.254.213 "tail -200 ~/gemini-audio-service.log | grep -A 50 '策略分析\|visual\|image_prompt' | tail -100"

echo ""
echo "========== 查看最近的 Gemini 响应 =========="
ssh admin@47.79.254.213 "tail -500 ~/gemini-audio-service.log | grep -A 20 'Gemini 响应内容' | tail -30"
