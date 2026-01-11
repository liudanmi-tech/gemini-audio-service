# 修复服务器 main.py 文件

## 问题
1. `google.generativeai` 包已弃用，但当前版本仍可使用
2. `genai.File` 类型注解有问题

## 解决方案

### 在服务器上执行：

```bash
cd ~/gemini-audio-service
source venv/bin/activate

# 修复 main.py 中的类型注解问题
# 将 genai.File 改为 Any 或删除类型注解
sed -i 's/genai\.File/Any/g' main.py

# 或者在文件开头添加 Any 导入
# 先检查是否需要添加
head -20 main.py | grep -q "from typing import.*Any" || sed -i '18a from typing import Any' main.py
```

### 或者直接修复文件：

```bash
cd ~/gemini-audio-service
source venv/bin/activate

# 使用 Python 修复
python3 << 'FIXEOF'
import re

with open('main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复类型注解：将 genai.File 改为 Any
content = content.replace('genai.File', 'Any')

# 确保导入了 Any
if 'from typing import' in content and 'Any' not in content.split('from typing import')[1].split('\n')[0]:
    content = content.replace(
        'from typing import List, Optional',
        'from typing import List, Optional, Any'
    )

with open('main.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ main.py 已修复")
FIXEOF

# 检查语法
python3 -m py_compile main.py
```

### 然后重新启动服务：

```bash
# 停止旧进程
pkill -f "python3 main.py"

# 启动服务
nohup python3 main.py > /tmp/gemini-service.log 2>&1 &

sleep 3

# 检查进程
ps aux | grep python3 | grep main.py

# 查看日志
tail -30 /tmp/gemini-service.log

# 测试 API
curl http://localhost:8001/health
```

