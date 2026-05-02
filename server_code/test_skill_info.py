"""
测试技能信息API
用于验证策略分析API是否正确返回技能信息
"""
import requests
import json
import sys

# 配置
BASE_URL = "http://47.79.254.213:8001"
SESSION_ID = "36ce0d4b-3a15-4382-9cd0-63b99397b10a"

# 需要先获取token（这里假设你已经登录）
# 或者使用已有的token
TOKEN = input("请输入JWT Token（或按Enter跳过，使用无token测试）: ").strip()

headers = {
    "Content-Type": "application/json"
}

if TOKEN:
    headers["Authorization"] = f"Bearer {TOKEN}"

print(f"========== 测试策略分析API ==========")
print(f"Session ID: {SESSION_ID}")
print(f"URL: {BASE_URL}/api/v1/tasks/sessions/{SESSION_ID}/strategies")
print()

# 调用策略分析API
response = requests.post(
    f"{BASE_URL}/api/v1/tasks/sessions/{SESSION_ID}/strategies",
    headers=headers,
    timeout=180
)

print(f"状态码: {response.status_code}")
print()

if response.status_code == 200:
    data = response.json()
    print("✅ 请求成功")
    print()
    
    if "data" in data:
        strategy_data = data["data"]
        
        print("策略分析数据:")
        print(f"  - 关键时刻数量: {len(strategy_data.get('visual', []))}")
        print(f"  - 策略数量: {len(strategy_data.get('strategies', []))}")
        print()
        
        # 检查技能信息
        applied_skills = strategy_data.get("applied_skills", [])
        scene_category = strategy_data.get("scene_category")
        scene_confidence = strategy_data.get("scene_confidence")
        
        print("技能信息:")
        if applied_skills:
            print(f"  ✅ 应用技能数量: {len(applied_skills)}")
            for i, skill in enumerate(applied_skills, 1):
                print(f"    技能 {i}:")
                print(f"      - skill_id: {skill.get('skill_id', 'N/A')}")
                print(f"      - priority: {skill.get('priority', 'N/A')}")
                print(f"      - confidence: {skill.get('confidence', 'N/A')}")
        else:
            print("  ⚠️ 未找到应用技能信息")
        
        print(f"  - 场景类别: {scene_category or 'N/A'}")
        print(f"  - 场景置信度: {scene_confidence or 'N/A'}")
        print()
        
        # 打印完整响应（用于调试）
        print("完整响应数据（前2000字符）:")
        print(json.dumps(data, ensure_ascii=False, indent=2)[:2000])
    else:
        print("❌ 响应中没有 'data' 字段")
        print("完整响应:")
        print(json.dumps(data, ensure_ascii=False, indent=2))
else:
    print(f"❌ 请求失败")
    print(f"响应内容: {response.text}")
