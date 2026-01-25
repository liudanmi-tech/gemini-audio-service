#!/bin/bash
# 上传修复 relationship 冲突的文件到服务器

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 上传修复 relationship 冲突的文件 =========="
echo ""

# 上传 database/models.py
echo "1. 上传 database/models.py..."
scp database/models.py $SERVER:$REMOTE_DIR/database/
if [ $? -eq 0 ]; then
    echo "✅ database/models.py 上传成功"
else
    echo "❌ database/models.py 上传失败"
    exit 1
fi

# 上传 api/profiles.py
echo ""
echo "2. 上传 api/profiles.py..."
scp api/profiles.py $SERVER:$REMOTE_DIR/api/
if [ $? -eq 0 ]; then
    echo "✅ api/profiles.py 上传成功"
else
    echo "❌ api/profiles.py 上传失败"
    exit 1
fi

echo ""
echo "========== 上传完成 =========="
echo ""
echo "请在服务器上执行以下命令重启服务："
echo "cd ~/gemini-audio-service"
echo "source venv/bin/activate"
echo "python3 -c \"from database.models import Profile, Skill; print('✅ 模型导入成功')\""
echo "pkill -f \"python.*main.py\""
echo "sleep 2"
echo "nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
echo "sleep 5"
echo "curl http://localhost:8001/api/v1/profiles"
