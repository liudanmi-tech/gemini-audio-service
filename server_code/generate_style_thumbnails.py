"""
一次性脚本：为前4种风格生成统一场景缩略图，压缩后上传到 OSS style_thumbnails/{style_key}.png
场景：金色头发的年轻人，站在山崖上，面朝大海，春暖花开
"""
import os, sys, time, io
sys.path.insert(0, '/home/admin/gemini-audio-service')

from dotenv import load_dotenv
load_dotenv('/home/admin/gemini-audio-service/.env')

import google.generativeai as genai
import oss2

GEMINI_API_KEY     = os.getenv("GEMINI_API_KEY")
OSS_ACCESS_KEY_ID  = os.getenv("OSS_ACCESS_KEY_ID")
OSS_ACCESS_KEY_SECRET = os.getenv("OSS_ACCESS_KEY_SECRET")
OSS_ENDPOINT       = os.getenv("OSS_ENDPOINT", "oss-cn-beijing.aliyuncs.com")
OSS_BUCKET_NAME    = os.getenv("OSS_BUCKET_NAME", "geminipicture2")

genai.configure(api_key=GEMINI_API_KEY)

endpoint = OSS_ENDPOINT if OSS_ENDPOINT.startswith("http") else f"https://{OSS_ENDPOINT}"
auth     = oss2.Auth(OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET)
bucket   = oss2.Bucket(auth, endpoint, OSS_BUCKET_NAME)

IMAGE_GEN_MODEL = "gemini-3.1-flash-image-preview"

# 相同的场景，不同风格
SCENE = (
    "金色头发的年轻人（看不清男女），独自站在山崖边缘，"
    "背对观众面朝大海，春暖花开，远处海天一线，花瓣随风飘散，微风轻抚。"
    "4:3 画面比例，横构图，画面唯美，不含任何文字。"
)

STYLES = {
    "ghibli": (
        "宫崎骏吉卜力动画风格：温暖自然色调、柔和手绘笔触、细腻光影、治愈系氛围。"
        "类似《龙猫》《千与千寻》的质感与色彩。\n\n"
    ),
    "shinkai": (
        "新海诚动画风格：高饱和蓝天、体积云与光线穿透、水面与玻璃反光。"
        "《你的名字》《天气之子》式的浪漫唯美画面。\n\n"
    ),
    "pixar": (
        "皮克斯 3D 动画风格：圆润角色建模、柔和体积光、细腻 PBR 材质、情感化表情。"
        "类似《寻梦环游记》《心灵奇旅》的照明与质感。\n\n"
    ),
    "cyberpunk": (
        "《赛博朋克2077》夜之城风格：主色调霓虹黄与青蓝，高对比暗部与霓虹高光。"
        "雨夜山崖、霓虹光反射海面、电影级光影。\n\n"
    ),
}

def generate_and_upload(style_key: str, style_prefix: str) -> bool:
    full_prompt = style_prefix + SCENE
    model = genai.GenerativeModel(IMAGE_GEN_MODEL)

    for attempt in range(3):
        try:
            print(f"  [{style_key}] attempt {attempt + 1}/3 generating...")
            t0 = time.time()
            response = model.generate_content(full_prompt)
            print(f"  [{style_key}] generated in {time.time()-t0:.1f}s")

            image_bytes = None
            for part in response.parts:
                if part.inline_data is not None:
                    image_bytes = part.inline_data.data
                    break

            if not image_bytes:
                print(f"  [{style_key}] no image in response, retrying...")
                time.sleep(3)
                continue

            # 压缩：缩放到 600x450 JPEG 82%，从 ~1.8MB 降到 ~60KB
            from PIL import Image as PILImage
            img = PILImage.open(io.BytesIO(image_bytes)).convert("RGB")
            img.thumbnail((600, 450), PILImage.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=82, optimize=True)
            compressed = buf.getvalue()
            print(f"  [{style_key}] compressed {len(image_bytes)//1024}KB -> {len(compressed)//1024}KB")

            oss_key = f"style_thumbnails/{style_key}.png"
            bucket.put_object(oss_key, compressed, headers={"Content-Type": "image/jpeg"})
            print(f"  ✅ [{style_key}] uploaded {len(compressed)} bytes -> {oss_key}")
            return True

        except Exception as e:
            print(f"  ❌ [{style_key}] attempt {attempt+1} error: {e}")
            if attempt < 2:
                time.sleep(5)

    return False


if __name__ == "__main__":
    print(f"OSS bucket: {OSS_BUCKET_NAME} endpoint: {OSS_ENDPOINT}")
    for style_key, style_prefix in STYLES.items():
        print(f"\n{'='*50}")
        print(f"生成风格: {style_key}")
        ok = generate_and_upload(style_key, style_prefix)
        if ok:
            print(f"✅ {style_key} 完成")
        else:
            print(f"❌ {style_key} 失败")
        if style_key != list(STYLES.keys())[-1]:
            time.sleep(4)  # rate limit

    print("\n全部完成")
