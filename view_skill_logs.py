#!/usr/bin/env python3
"""
查看指定session的技能信息和日志
"""
import subprocess
import sys

SESSION_ID = "14979abf-41a7-4d00-a2f8-bfe0cebfffab"

print(f"========== 查看 Session 技能信息 ==========")
print(f"Session ID: {SESSION_ID}")
print()

# 1. 查看服务器日志
print("1. 查看服务器日志（包含该session）...")
print("-" * 60)
cmd = f'ssh admin@47.79.254.213 "tail -2000 ~/gemini-audio-service.log | grep \\"{SESSION_ID}\\" | tail -50"'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
if result.stdout:
    print(result.stdout)
else:
    print("未找到相关日志")
print()

# 2. 查看策略分析相关日志
print("2. 查看策略分析生成日志...")
print("-" * 60)
cmd = f'ssh admin@47.79.254.213 "tail -3000 ~/gemini-audio-service.log | grep -E \\"策略分析生成|场景识别|技能匹配|v0.4|applied_skills|scene_category|14979abf\\" | tail -100"'
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
if result.stdout:
    print(result.stdout)
else:
    print("未找到相关日志")
print()

# 3. 查看数据库
print("3. 查看数据库中的技能信息...")
print("-" * 60)
cmd = f'''ssh admin@47.79.254.213 << 'DBEOF'
cd ~/gemini-audio-service
source venv/bin/activate
python3 << 'PYEOF'
import asyncio
import asyncpg
import os
from dotenv import load_dotenv
from urllib.parse import urlparse

load_dotenv()

async def check():
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
    
    session_id = "{SESSION_ID}"
    
    result = await conn.fetchrow("""
        SELECT 
            applied_skills,
            scene_category,
            scene_confidence,
            created_at
        FROM strategy_analysis
        WHERE session_id = $1
    """, session_id)
    
    if result:
        print("✅ 找到策略分析数据")
        print(f"创建时间: {{result['created_at']}}")
        print()
        print("📊 技能信息:")
        print(f"  - 场景类别: {{result['scene_category'] or 'N/A'}}")
        print(f"  - 场景置信度: {{result['scene_confidence'] or 'N/A'}}")
        
        applied_skills = result['applied_skills'] or []
        print(f"  - 应用技能数量: {{len(applied_skills)}}")
        print()
        
        if applied_skills:
            for i, skill in enumerate(applied_skills, 1):
                print(f"  技能 {{i}}:")
                print(f"    - skill_id: {{skill.get('skill_id', 'N/A')}}")
                print(f"    - priority: {{skill.get('priority', 'N/A')}}")
                print(f"    - confidence: {{skill.get('confidence', 'N/A')}}")
            print()
            
            # 读取技能详情
            print("📄 技能详情 (SKILL.md):")
            print("=" * 60)
            for skill in applied_skills:
                skill_id = skill.get('skill_id')
                if skill_id:
                    skill_path = f"skills/{{skill_id}}/SKILL.md"
                    try:
                        with open(skill_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                            print(f"\\n{{'=' * 60}}")
                            print(f"技能: {{skill_id}}")
                            print(f"{{'=' * 60}}")
                            print(content)
                            print()
                    except FileNotFoundError:
                        print(f"❌ 技能文件不存在: {{skill_path}}")
                    except Exception as e:
                        print(f"❌ 读取技能文件失败: {{e}}")
        else:
            print("  ⚠️ 未找到应用技能信息")
    else:
        print("❌ 未找到策略分析数据")
    
    await conn.close()

asyncio.run(check())
PYEOF
DBEOF
'''
result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
if result.stdout:
    print(result.stdout)
if result.stderr:
    print("错误:", result.stderr)

print()
print("=" * 60)
