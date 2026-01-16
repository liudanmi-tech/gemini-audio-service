#!/bin/bash

# 检查服务器上的导入顺序

echo "========== 检查服务器上的导入语句 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

echo "=== 第21行（FastAPI导入）==="
sed -n '21p' main.py

echo ""
echo "=== 第53行（JWT导入）==="
sed -n '53p' main.py

echo ""
echo "=== 第939行（使用Depends的地方）==="
sed -n '939p' main.py

echo ""
echo "=== 检查所有FastAPI导入 ==="
grep -n "from fastapi import" main.py

echo ""
echo "=== 检查Depends的使用 ==="
grep -n "Depends" main.py | head -5
EOF
