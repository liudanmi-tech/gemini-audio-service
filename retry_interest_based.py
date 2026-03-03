#!/usr/bin/env python3
"""重试 interest_based 封面图：本地生成 → 保存 → 在服务器上传 OSS → 更新 SKILL.md"""
import sys, os, time, logging, re, subprocess, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.abspath(__file__)))

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
logger = logging.getLogger(__name__)

import google.generativeai as genai

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
genai.configure(api_key=GEMINI_API_KEY)

ASIAN_TAG = "East Asian faces, Chinese family scene, "
MODEL = "gemini-3.1-flash-image-preview"

PROMPT = (
    ASIAN_TAG +
    "Pixar 3D animation style, warm purple-blue tones. "
    "A couple sits at a round dining table covered with maps, budget sheets and city photos. "
    "The husband points to one location while the wife points to another, both looking earnest but warm. "
    "A large whiteboard behind them has two columns labeled 'My Concerns' and 'Your Concerns'. "
    "Soft evening light, cozy home setting. "
    "Style: Pixar 3D, rich textures, warm colors."
)

def generate_image(prompt, max_retries=5):
    model = genai.GenerativeModel(MODEL)
    for attempt in range(1, max_retries + 1):
        try:
            logger.info(f"[interest_based] 生成中... (attempt {attempt})")
            t0 = time.time()
            resp = model.generate_content(
                [{"role": "user", "parts": [{"text": prompt}]}],
                generation_config={"response_modalities": ["IMAGE", "TEXT"]},
            )
            elapsed = time.time() - t0
            logger.info(f"[interest_based] 耗时 {elapsed:.1f}s")
            for part in resp.candidates[0].content.parts:
                if hasattr(part, "inline_data") and part.inline_data and part.inline_data.data:
                    data = part.inline_data.data
                    if isinstance(data, str):
                        import base64
                        data = base64.b64decode(data)
                    if len(data) > 1000:
                        logger.info(f"[interest_based] ✅ {len(data):,} bytes")
                        return data
            logger.warning(f"[interest_based] ⚠️ 无图片数据")
        except Exception as e:
            logger.error(f"[interest_based] 异常: {e}")
        if attempt < max_retries:
            time.sleep(3)
    return None

if __name__ == "__main__":
    data = generate_image(PROMPT)
    if not data:
        logger.error("❌ 图片生成失败")
        sys.exit(1)

    # 保存到临时文件
    tmp_path = "/tmp/interest_based_pixar.png"
    with open(tmp_path, "wb") as f:
        f.write(data)
    logger.info(f"✅ 图片已保存: {tmp_path}")

    # scp 到北京服务器
    logger.info("📤 上传到北京服务器...")
    r = subprocess.run([
        "sshpass", "-p", "LD123456zhoudabao",
        "scp", tmp_path, "root@123.57.29.111:/tmp/interest_based_pixar.png"
    ], capture_output=True, text=True)
    if r.returncode != 0:
        logger.error(f"❌ scp 失败: {r.stderr}")
        sys.exit(1)
    logger.info("✅ scp 成功")

    # 在服务器上用 Python 上传到 OSS
    upload_cmd = """python3 -c "
import oss2, os
auth = oss2.Auth(os.environ['OSS_ACCESS_KEY_ID'], os.environ['OSS_ACCESS_KEY_SECRET'])
bucket = oss2.Bucket(auth, 'oss-cn-beijing.aliyuncs.com', 'geminipicture2')
with open('/tmp/interest_based_pixar.png', 'rb') as f:
    data = f.read()
result = bucket.put_object('skill_covers/interest_based_pixar.png', data)
print(f'status={result.status}')
if result.status == 200:
    print('https://geminipicture2.oss-cn-beijing.aliyuncs.com/skill_covers/interest_based_pixar.png')
"
"""
    r2 = subprocess.run(
        ["sshpass", "-p", "LD123456zhoudabao",
         "ssh", "root@123.57.29.111",
         "cd /root/gemini-audio-service && set -a && source .env && set +a && /root/gemini-audio-service/venv/bin/python3 -c \"" +
         upload_cmd.replace('"', '\\"').replace('\n', ' ') + "\""],
        capture_output=True, text=True
    )
    output = r2.stdout.strip()
    logger.info(f"服务器输出: {output}")
    if r2.returncode != 0:
        logger.error(f"❌ 上传失败: {r2.stderr}")
        sys.exit(1)

    # 提取 URL
    url = None
    for line in output.splitlines():
        if line.startswith("https://"):
            url = line.strip()
            break
    if not url:
        logger.error(f"❌ 未获取到 URL，输出: {output}")
        sys.exit(1)

    logger.info(f"✅ OSS URL: {url}")

    # 更新 SKILL.md
    path = "skills/couple_decision/SKILL.md"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    pattern = r'(  - id: interest_based\n(?:(?!  - id:)[\s\S])*?    cover_image:) ""'
    new_content = re.sub(pattern, rf'\1 "{url}"', content)
    if new_content == content:
        logger.warning("⚠️ 未找到 cover_image 占位符")
    else:
        with open(path, "w", encoding="utf-8") as f:
            f.write(new_content)
        logger.info(f"✅ 已写入 skills/couple_decision/SKILL.md: interest_based.cover_image")

    logger.info("🎉 interest_based 完成！")
