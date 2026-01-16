#!/bin/bash
# 更新.env文件，添加数据库和认证相关配置

ENV_FILE=".env"

# 检查.env文件是否存在
if [ ! -f "$ENV_FILE" ]; then
    echo "创建新的.env文件..."
    cp .env.example .env
fi

# 添加数据库配置（如果不存在）
if ! grep -q "^DATABASE_URL=" "$ENV_FILE"; then
    echo "" >> "$ENV_FILE"
    echo "# 数据库配置" >> "$ENV_FILE"
    echo "DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/gemini_audio_db" >> "$ENV_FILE"
fi

# 添加JWT配置（如果不存在）
if ! grep -q "^JWT_SECRET_KEY=" "$ENV_FILE"; then
    echo "" >> "$ENV_FILE"
    echo "# JWT配置" >> "$ENV_FILE"
    echo "JWT_SECRET_KEY=your-secret-key-here-change-in-production" >> "$ENV_FILE"
    echo "JWT_ALGORITHM=HS256" >> "$ENV_FILE"
    echo "JWT_EXPIRATION_HOURS=24" >> "$ENV_FILE"
fi

# 添加验证码配置（如果不存在）
if ! grep -q "^VERIFICATION_CODE_MOCK=" "$ENV_FILE"; then
    echo "" >> "$ENV_FILE"
    echo "# 验证码配置（开发阶段）" >> "$ENV_FILE"
    echo "VERIFICATION_CODE_MOCK=true" >> "$ENV_FILE"
    echo "VERIFICATION_CODE_MOCK_VALUE=123456" >> "$ENV_FILE"
    echo "VERIFICATION_CODE_EXPIRY_MINUTES=5" >> "$ENV_FILE"
fi

echo "✅ .env文件配置已更新"
