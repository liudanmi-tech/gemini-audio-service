#!/bin/bash

# 检查服务器上的导入语句并修复

echo "========== 1. 检查服务器上的导入语句 =========="
ssh admin@47.79.254.213 'grep "from fastapi import" ~/gemini-audio-service/main.py | head -1'

echo ""
echo "========== 2. 重新上传代码 =========="
cd ~/Desktop/AI军师/gemini-audio-service
scp main.py admin@47.79.254.213:~/gemini-audio-service/

echo ""
echo "========== 3. 验证服务器上的导入语句 =========="
ssh admin@47.79.254.213 'grep "from fastapi import" ~/gemini-audio-service/main.py | head -1'

echo ""
echo "========== 4. 如果还是不对，直接在服务器上修复 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

# 检查当前导入
echo "修复前的导入："
grep "from fastapi import" main.py | head -1

# 修复导入（如果Depends不在其中）
sed -i 's/from fastapi import FastAPI, UploadFile, File, HTTPException, Query$/from fastapi import FastAPI, UploadFile, File, HTTPException, Query, Depends/' main.py
sed -i 's/from fastapi import FastAPI, UploadFile, File, HTTPException, Query, Depends$/from fastapi import FastAPI, UploadFile, File, HTTPException, Query, Depends/' main.py

# 验证修复
echo "修复后的导入："
grep "from fastapi import" main.py | head -1

# 检查语法
source venv/bin/activate
python3 -m py_compile main.py 2>&1 | head -5
EOF
