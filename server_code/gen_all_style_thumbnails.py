"""
批量生成所有风格缩略图（跳过已存在的 ghibli/shinkai/pixar，重新生成 cyberpunk 和其余19种）
场景统一：金色头发年轻人，站山崖，面朝大海，春暖花开
"""
import os, sys, time, io
sys.path.insert(0, '/home/admin/gemini-audio-service')

from dotenv import load_dotenv
load_dotenv('/home/admin/gemini-audio-service/.env')

import google.generativeai as genai
import oss2
from PIL import Image as PILImage

GEMINI_API_KEY    = os.getenv("GEMINI_API_KEY")
OSS_ACCESS_KEY_ID = os.getenv("OSS_ACCESS_KEY_ID")
OSS_ACCESS_KEY_SECRET = os.getenv("OSS_ACCESS_KEY_SECRET")
OSS_ENDPOINT      = os.getenv("OSS_ENDPOINT", "oss-cn-beijing.aliyuncs.com")
OSS_BUCKET_NAME   = os.getenv("OSS_BUCKET_NAME", "geminipicture2")

genai.configure(api_key=GEMINI_API_KEY)
endpoint = OSS_ENDPOINT if OSS_ENDPOINT.startswith("http") else f"https://{OSS_ENDPOINT}"
auth     = oss2.Auth(OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET)
bucket   = oss2.Bucket(auth, endpoint, OSS_BUCKET_NAME)

IMAGE_GEN_MODEL = "gemini-3.1-flash-image-preview"

SCENE = (
    "金色头发的年轻人（看不清男女），独自站在山崖边缘，"
    "背对观众面朝大海，春暖花开，远处海天一线，花瓣随风飘散，微风轻抚。"
    "4:3 横构图，画面唯美，不含任何文字。"
)

# 全部23种风格（ghibli/shinkai/pixar 已有可跳过，cyberpunk 重新生成）
STYLES = {
    "cyberpunk":      "赛博朋克2077风格：主色调霓虹蓝与紫，高对比暗部与霓虹高光，夜之城感。雨夜山崖、霓虹光反射海面、电影级光影。\n\n",
    "watercolor":     "水彩插画风格：晕染边缘、透明叠色、留白与纸纹、清新自然。类似儿童绘本或插画集的水彩质感。\n\n",
    "ukiyoe":         "日式浮世绘风格：平面构图、黑色勾线描边、传统配色（靛蓝、朱红、浅绿）。葛饰北斋或歌川广重的经典浮世绘美感。\n\n",
    "clay":           "粘土定格动画风格：圆润立体的粘土质感、手工捏制纹理、柔和工作室灯光。类似Aardman的温暖幽默感，人物圆润可爱，背景精细手工感。\n\n",
    "felt":           "毛毡布艺风格：布料纤维质感、手工缝制细节、温暖饱和色彩。类似北欧手工艺品的温馨触感，边缘有轻微毛绒感。\n\n",
    "noir_manga":     "浦泽直树写实漫画风格：极度写实的人物面孔、细腻心理刻画、繁复背景、精细交叉排线光影。黑白强对比，人物眼神深邃。\n\n",
    "rembrandt":      "伦勃朗古典人像风格：单侧强光打脸、深邃眼神、暗部丰富细节、画布油彩质感。17世纪荷兰黄金时代肖像风，背景深暗人物发光。\n\n",
    "constructivism": "苏联先锋派构成主义海报风格：强烈对角线构图、红黑撞色、几何图形与人物剪影。Rodchenko的革命张力，充满力量感。\n\n",
    "jojo":           "荒木飞吕彦JoJo漫画风格：夸张戏剧性pose、时尚杂志感构图、装饰性花纹背景、类文艺复兴雕塑质感。色彩大胆，线条张力十足。\n\n",
    "toriyama":       "鸟山明龙珠热血漫画风格：圆润干净的线条、活泼动感、夸张表情与特效、明快色彩。少年热血感，充满活力。\n\n",
    "clamp":          "CLAMP四人组漫画风格：极细长的人体比例、华丽繁复的服装细节、唯美命运感构图、精致的眼睛与发丝。史诗唯美感。\n\n",
    "line_art":       "极简黑白线稿风格：纯黑白、细线条勾勒、大量留白、极少阴影。类似漫画分镜或手绘草图的极简美感。\n\n",
    "steampunk":      "蒸汽朋克风格：铜黄机械、齿轮管道、维多利亚时代服饰、复古工业美学。蒸汽机与飞艇的复古科幻感。\n\n",
    "pop_art":        "波普艺术风格：粗黑轮廓线、高饱和纯色块、网点纹理、强对比。类似安迪·沃霍尔或Roy Lichtenstein的波普美感。\n\n",
    "scandinavian":   "北欧插画风格：扁平色块、低饱和度、几何简约、温馨治愈。斯堪的纳维亚绘本的柔和与克制。\n\n",
    "retro_manga":    "昭和复古漫画风格：网点纸纹理、粗边框、怀旧暖色调。类似80年代日本漫画的网点与线条美感。\n\n",
    "oil_painting":   "古典油画风格：厚涂笔触、伦勃朗式明暗、暖色光感、画布质感。类似伦勃朗或印象派的古典构图与质感。\n\n",
    "pixel":          "16-bit 像素游戏风格：方色块、有限色板、HD-2D景深。类似《八方旅人》的复古游戏质感，颗粒感鲜明。\n\n",
    "chinese_ink":    "中国水墨画风格：墨分五色（焦浓重淡清）、宣纸晕染、大量留白、写意笔触。传统山水水墨的淡雅诗意。\n\n",
    "storybook":      "欧洲童话绘本风格：柔和水彩、复古装帧感、梦幻氛围。类似《小王子》插图的温馨与幻想质感。\n\n",
}

# 已存在且质量OK的跳过
SKIP_IF_EXISTS = {"ghibli", "shinkai", "pixar"}

def exists_on_oss(style_key: str) -> bool:
    if style_key in SKIP_IF_EXISTS:
        return True
    try:
        bucket.head_object(f"style_thumbnails/{style_key}.png")
        return False  # 已有但强制重生成（cyberpunk等）
    except Exception:
        return False

def generate_and_upload(style_key: str, style_prefix: str) -> bool:
    full_prompt = style_prefix + SCENE
    model = genai.GenerativeModel(IMAGE_GEN_MODEL)

    for attempt in range(4):
        try:
            print(f"  attempt {attempt+1}/4 generating...")
            t0 = time.time()
            response = model.generate_content(full_prompt)
            print(f"  generated in {time.time()-t0:.1f}s")

            image_bytes = None
            for part in response.parts:
                if part.inline_data is not None:
                    image_bytes = part.inline_data.data
                    break

            if not image_bytes:
                print(f"  no image in response, retrying...")
                time.sleep(15)
                continue

            # 压缩：缩放到 600x450 JPEG 82%
            img = PILImage.open(io.BytesIO(image_bytes)).convert("RGB")
            img.thumbnail((600, 450), PILImage.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=82, optimize=True)
            compressed = buf.getvalue()
            print(f"  compressed {len(image_bytes)//1024}KB -> {len(compressed)//1024}KB")

            oss_key = f"style_thumbnails/{style_key}.png"
            bucket.put_object(oss_key, compressed, headers={"Content-Type": "image/jpeg"})
            print(f"  ✅ uploaded {len(compressed)//1024}KB -> {oss_key}")
            return True

        except Exception as e:
            err_str = str(e)
            if "429" in err_str:
                wait = 65 * (attempt + 1)   # 429 时指数等待：65s / 130s / 195s
                print(f"  ⏳ 429 限速，等待 {wait}s 后重试...")
                time.sleep(wait)
            else:
                print(f"  ❌ attempt {attempt+1} error: {e}")
                if attempt < 3:
                    time.sleep(10)
    return False


if __name__ == "__main__":
    styles_list = list(STYLES.items())
    total = len(styles_list)
    print(f"共 {total} 种风格待生成\n")

    failed = []
    for i, (style_key, style_prefix) in enumerate(styles_list):
        print(f"[{i+1}/{total}] {style_key}")
        ok = generate_and_upload(style_key, style_prefix)
        if not ok:
            failed.append(style_key)
        if i < total - 1:
            time.sleep(20)   # 两张图之间至少间隔20s，避免触发 RPM 限速

    print(f"\n{'='*50}")
    print(f"完成 {total - len(failed)}/{total}")
    if failed:
        print(f"失败: {failed}")
