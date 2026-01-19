#!/bin/bash
# 查询指定session的技能信息

SESSION_ID="14979abf-41a7-4d00-a2f8-bfe0cebfffab"

echo "========== 查询 Session 技能信息 =========="
echo "Session ID: $SESSION_ID"
echo ""
echo "根据日志分析："
echo "  - 场景识别结果: primary_scene=workplace"
echo "  - 技能匹配完成：匹配到 1 个技能"
echo "  - 根据场景类别 'workplace'，应该匹配到 'workplace_jungle' 技能"
echo ""
echo "正在查询数据库确认..."
echo ""

ssh admin@47.79.254.213 << EOF
cd ~/gemini-audio-service
source venv/bin/activate

python3 << 'PYEOF'
import asyncio
import asyncpg
import os
from dotenv import load_dotenv
from urllib.parse import urlparse

load_dotenv()

async def query():
    database_url = os.getenv("DATABASE_URL", "")
    if "postgresql+asyncpg://" in database_url:
        database_url = database_url.replace("postgresql+asyncpg://", "postgresql://")
    
    parsed = urlparse(database_url)
    
    conn = await asyncpg.connect(
        host=parsed.hostname or 'localhost',
        port=parsed.port or 5432,
        user=parsed.username or 'postgres',
        password=parsed.password or 'postgres',
        database=parsed.path.lstrip('/') or 'gemini_audio_db'
    )
    
    session_id = "$SESSION_ID"
    
    result = await conn.fetchrow("""
        SELECT 
            applied_skills,
            scene_category,
            scene_confidence,
            created_at
        FROM strategy_analysis
        WHERE session_id = $1
    """, session_id)
    
    print("=" * 80)
    if result:
        print("✅ 找到策略分析数据")
        print("=" * 80)
        print(f"创建时间: {result['created_at']}")
        print()
        print("📊 场景信息:")
        print(f"  - 场景类别: {result['scene_category'] or 'N/A'}")
        print(f"  - 场景置信度: {result['scene_confidence'] or 'N/A'}")
        print()
        
        applied_skills = result['applied_skills'] or []
        print(f"🎯 应用的技能: {len(applied_skills)} 个")
        print()
        
        if applied_skills:
            for i, skill in enumerate(applied_skills, 1):
                skill_id = skill.get('skill_id', 'N/A')
                priority = skill.get('priority', 'N/A')
                confidence = skill.get('confidence', 'N/A')
                
                print(f"技能 {i}:")
                print(f"  ✅ skill_id: {skill_id}")
                print(f"  - priority: {priority}")
                print(f"  - confidence: {confidence}")
                print()
                
                # 读取技能详情
                if skill_id != 'N/A':
                    skill_path = f"skills/{skill_id}/SKILL.md"
                    try:
                        with open(skill_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            print("=" * 80)
                            print(f"📄 技能详情 (SKILL.md): {skill_id}")
                            print("=" * 80)
                            print(content)
                            print()
                    except FileNotFoundError:
                        print(f"  ❌ 技能文件不存在: {skill_path}")
                    except Exception as e:
                        print(f"  ❌ 读取技能文件失败: {e}")
        else:
            print("  ⚠️ 未找到应用技能信息")
            print("  可能原因：策略分析是在v0.4架构部署之前生成的")
    else:
        print("❌ 未找到策略分析数据")
    print("=" * 80)
    
    await conn.close()

asyncio.run(query())
PYEOF

EOF
