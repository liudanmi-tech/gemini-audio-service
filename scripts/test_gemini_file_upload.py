#!/usr/bin/env python3
"""
测试 Gemini 文件上传（真正调用 upload_file，定位 0.5 卡住问题）
在服务器执行: cd ~/gemini-audio-service && source venv/bin/activate && python scripts/test_gemini_file_upload.py
"""
import os
import sys
import tempfile

from pathlib import Path
env_path = Path(__file__).resolve().parent.parent / ".env"
if env_path.exists():
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

def main():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("❌ GEMINI_API_KEY 未设置")
        sys.exit(1)

    no_proxy = os.getenv("GEMINI_FILE_UPLOAD_NO_PROXY", "").lower() == "true"
    timeout = int(os.getenv("GEMINI_UPLOAD_TIMEOUT", "90"))
    print(f"NO_PROXY={no_proxy}, timeout={timeout}s")
    print()

    # 创建最小可用的 m4a 占位文件（约 1KB，用于测试上传逻辑，不要求真实音频）
    sample_content = b"\x00" * 1024
    with tempfile.NamedTemporaryFile(suffix=".m4a", delete=False) as f:
        f.write(sample_content)
        temp_path = f.name

    try:
        import google.generativeai as genai
        genai.configure(api_key=api_key)

        if no_proxy:
            try:
                import google.generativeai.client as _gc
                _gc.GENAI_API_DISCOVERY_URL = "https://generativelanguage.googleapis.com/$discovery/rest"
                print("✅ 已切换为直连（NO_PROXY）")
            except Exception as e:
                print(f"⚠️ 切换直连失败: {e}")

        print("开始调用 genai.upload_file()...")
        import concurrent.futures
        import time
        start = time.time()
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as ex:
            fut = ex.submit(
                genai.upload_file,
                path=temp_path,
                display_name="test_upload.m4a",
                resumable=False,  # 先用简单上传
            )
            try:
                uploaded = fut.result(timeout=timeout)
                elapsed = time.time() - start
                print(f"✅ 文件上传成功！name={uploaded.name}, state={uploaded.state}, 耗时 {elapsed:.2f}s")
            except concurrent.futures.TimeoutError:
                print(f"❌ 上传超时（{timeout}s），Files API 可能不可达")
                sys.exit(1)
            except Exception as e:
                print(f"❌ 上传失败: {type(e).__name__}: {e}")
                import traceback
                traceback.print_exc()
                sys.exit(1)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)

    print()
    print("========== 文件上传测试通过 ==========")

if __name__ == "__main__":
    main()
