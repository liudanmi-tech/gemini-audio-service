"""
压缩 OSS 上的风格缩略图：下载 → Pillow 缩放到 600x450 JPEG 85% → 回传
"""
import os, sys, io
sys.path.insert(0, '/home/admin/gemini-audio-service')

from dotenv import load_dotenv
load_dotenv('/home/admin/gemini-audio-service/.env')

import oss2
from PIL import Image

OSS_ACCESS_KEY_ID  = os.getenv("OSS_ACCESS_KEY_ID")
OSS_ACCESS_KEY_SECRET = os.getenv("OSS_ACCESS_KEY_SECRET")
OSS_ENDPOINT       = os.getenv("OSS_ENDPOINT", "oss-cn-beijing.aliyuncs.com")
OSS_BUCKET_NAME    = os.getenv("OSS_BUCKET_NAME", "geminipicture2")

endpoint = OSS_ENDPOINT if OSS_ENDPOINT.startswith("http") else f"https://{OSS_ENDPOINT}"
auth     = oss2.Auth(OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET)
bucket   = oss2.Bucket(auth, endpoint, OSS_BUCKET_NAME)

TARGET_W, TARGET_H = 600, 450   # 4:3，Retina 显示足够
JPEG_QUALITY = 82

STYLES = ["ghibli", "shinkai", "pixar", "cyberpunk"]

for style_key in STYLES:
    oss_key = f"style_thumbnails/{style_key}.png"
    print(f"\n[{style_key}] 下载中...")

    try:
        obj = bucket.get_object(oss_key)
        raw = obj.read()
        print(f"  原始大小: {len(raw)/1024:.0f} KB")

        img = Image.open(io.BytesIO(raw)).convert("RGB")
        print(f"  原始尺寸: {img.size}")

        # 保持比例缩放，不超过 TARGET_W x TARGET_H
        img.thumbnail((TARGET_W, TARGET_H), Image.LANCZOS)
        print(f"  压缩后尺寸: {img.size}")

        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=JPEG_QUALITY, optimize=True)
        compressed = buf.getvalue()
        print(f"  压缩后大小: {len(compressed)/1024:.0f} KB  压缩率: {len(compressed)/len(raw)*100:.1f}%")

        # 回传（key 保持 .png 不变，content-type 改为 jpeg）
        bucket.put_object(oss_key, compressed, headers={"Content-Type": "image/jpeg"})
        print(f"  ✅ 上传完成")

    except Exception as e:
        print(f"  ❌ 失败: {e}")

print("\n全部完成")
