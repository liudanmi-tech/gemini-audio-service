"""
测试档案 API 路由是否正确注册
"""
import requests

base_url = "http://47.79.254.213:8001"

# 测试路由是否存在
endpoints = [
    "/api/v1/profiles",
    "/profiles",
    "/api/v1/auth/login",
    "/api/v1/skills",
]

print("测试路由是否存在：")
for endpoint in endpoints:
    try:
        response = requests.get(f"{base_url}{endpoint}", timeout=5)
        print(f"✅ {endpoint}: {response.status_code}")
    except Exception as e:
        print(f"❌ {endpoint}: {e}")
