#!/bin/bash
# 上传 main.py 到服务器（使用 base64 编码）

echo "📤 开始上传 main.py 到服务器..."

# 读取文件并 base64 编码
ENCODED=$(python3 -c "import base64; print(base64.b64encode(open('main.py', 'rb').read()).decode('utf-8'))")

# 在服务器上解码并写入文件
ssh admin@47.79.254.213 << EOF
cd ~/gemini-audio-service
cp main.py main.py.backup6
python3 -c "
import base64
content = base64.b64decode('$ENCODED').decode('utf-8')
with open('main.py', 'w', encoding='utf-8') as f:
    f.write(content)
print('✅ 文件已写入')
import py_compile
py_compile.compile('main.py', doraise=True)
print('✅ 语法检查通过')
"
EOF

echo "✅ 上传完成！"

