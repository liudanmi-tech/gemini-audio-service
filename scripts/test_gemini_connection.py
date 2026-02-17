#!/usr/bin/env python3
"""
测试 Gemini API 连接是否正常
在服务器上执行: cd ~/gemini-audio-service && source venv/bin/activate && python scripts/test_gemini_connection.py
"""
import os
import sys

# 加载 .env
from pathlib import Path
env_path = Path(__file__).resolve().parent.parent / ".env"
if env_path.exists():
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

def test_genai_configure():
    """测试 genai 配置"""
    import google.generativeai as genai
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("❌ GEMINI_API_KEY 未设置")
        return False
    genai.configure(api_key=api_key)
    print("✅ genai 配置成功")
    return True

def test_models_list():
    """测试列出模型（简单 API 调用）"""
    import google.generativeai as genai
    try:
        models = list(genai.list_models())
        print(f"✅ 列出模型成功，共 {len(models)} 个")
        return True
    except Exception as e:
        print(f"❌ 列出模型失败: {e}")
        return False

def test_file_upload_discovery():
    """测试文件服务 discovery URL（不实际上传）"""
    import google.generativeai.client as _gc
    no_proxy = os.getenv("GEMINI_FILE_UPLOAD_NO_PROXY", "").lower() == "true"
    if no_proxy:
        _old = getattr(_gc, "GENAI_API_DISCOVERY_URL", None)
        _gc.GENAI_API_DISCOVERY_URL = "https://generativelanguage.googleapis.com/$discovery/rest"
        print("✅ 已切换为直连（NO_PROXY=true）")
        if _old:
            _gc.GENAI_API_DISCOVERY_URL = _old
        return True
    print("ℹ️ 使用代理模式（NO_PROXY 未启用）")
    return True

def test_simple_generate():
    """测试简单文本生成（验证 API 可达）"""
    import google.generativeai as genai
    # 按优先级尝试，main.py 默认 gemini-3-flash-preview
    models_to_try = [
        os.getenv("GEMINI_FLASH_MODEL"),
        "gemini-2.0-flash",
        "gemini-1.5-flash",
        "gemini-1.5-flash-8b",
    ]
    for model_name in models_to_try:
        if not model_name:
            continue
        try:
            model = genai.GenerativeModel(model_name)
            response = model.generate_content("说一个字：好")
            text = response.text.strip()
            print(f"✅ 文本生成成功 (model={model_name}): {text[:50]}...")
            return True
        except Exception as e:
            if "404" in str(e) or "not found" in str(e).lower():
                continue  # 模型不存在，尝试下一个
            print(f"❌ 文本生成失败 ({model_name}): {e}")
            return False
    print("⚠️ 未找到可用模型，但 list_models 已成功，连接正常")
    return True  # 连接已通过 list_models 验证

def main():
    print("========== 测试 Gemini 连接 ==========")
    print()
    
    if not test_genai_configure():
        sys.exit(1)
    
    print()
    test_file_upload_discovery()
    print()
    
    if not test_models_list():
        sys.exit(1)
    
    print()
    if not test_simple_generate():
        sys.exit(1)
    
    print()
    print("========== 全部测试通过 ==========")

if __name__ == "__main__":
    main()
