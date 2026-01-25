#!/bin/bash
# 上传 database/models.py 到服务器

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 上传 database/models.py 到服务器 =========="
echo ""

# 检查文件是否存在
if [ ! -f "database/models.py" ]; then
    echo "❌ database/models.py 文件不存在"
    exit 1
fi

# 上传文件
echo "上传 database/models.py..."
scp database/models.py $SERVER:$REMOTE_DIR/database/
if [ $? -eq 0 ]; then
    echo "✅ database/models.py 上传成功"
else
    echo "❌ database/models.py 上传失败"
    exit 1
fi

echo ""
echo "========== 上传完成 =========="
echo ""
echo "请在服务器上执行以下命令："
echo "1. cd ~/gemini-audio-service"
echo "2. source venv/bin/activate"
echo "3. python3 -c 'from database.models import Profile; print(\"✅ Profile 模型导入成功\")'"
echo "4. pkill -f \"python.*main.py\""
echo "5. nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
echo "6. sleep 5"
echo "7. curl http://localhost:8001/api/v1/profiles"
