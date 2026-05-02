import sys

# 读取原文件
with open('main.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 找到 _fetch_profile_image_from_oss 函数的位置
insert_line = None
for i, line in enumerate(lines):
    if 'def _fetch_profile_image_from_oss' in line:
        insert_line = i
        break

if insert_line is None:
    print('Error: 找不到 _fetch_profile_image_from_oss 函数')
    sys.exit(1)

# 新的压缩函数
compress_func = '''def _compress_profile_image(data: bytes, mime: str, max_size_kb: int = 300) -> Tuple[bytes, str]:
    """
    压缩档案照片，用于图片生成参考。
    目标：将大图压缩到 300KB 以内，加快 Gemini API 处理速度。
    """
    from PIL import Image
    import io

    original_size = len(data)
    if original_size <= max_size_kb * 1024:
        logger.debug(f"[档案照片] 图片已足够小 ({original_size} bytes)，无需压缩")
        return (data, mime)

    try:
        img = Image.open(io.BytesIO(data))

        # 转换为 RGB
        if img.mode in ('RGBA', 'LA', 'P'):
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'P':
                img = img.convert('RGBA')
            if img.mode in ('RGBA', 'LA'):
                background.paste(img, mask=img.split()[-1])
            else:
                background.paste(img)
            img = background
        elif img.mode != 'RGB':
            img = img.convert('RGB')

        # 调整尺寸（长边不超过 1024px）
        max_dimension = 1024
        width, height = img.size
        if max(width, height) > max_dimension:
            if width > height:
                new_width = max_dimension
                new_height = int(height * max_dimension / width)
            else:
                new_height = max_dimension
                new_width = int(width * max_dimension / height)
            img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            logger.info(f"[档案照片] 调整尺寸: {width}x{height} -> {new_width}x{new_height}")

        # 二分查找最佳质量
        quality = 85
        output = io.BytesIO()
        img.save(output, format='JPEG', quality=quality, optimize=True)
        compressed_data = output.getvalue()

        attempts = 0
        while len(compressed_data) > max_size_kb * 1024 and quality > 50 and attempts < 5:
            quality -= 10
            output = io.BytesIO()
            img.save(output, format='JPEG', quality=quality, optimize=True)
            compressed_data = output.getvalue()
            attempts += 1

        compressed_size = len(compressed_data)
        compression_ratio = (1 - compressed_size / original_size) * 100
        logger.info(f"[档案照片] 压缩完成: {original_size} bytes -> {compressed_size} bytes ({compression_ratio:.1f}% 减少), quality={quality}")

        return (compressed_data, "image/jpeg")
    except Exception as e:
        logger.warning(f"[档案照片] 压缩失败: {e}，使用原图")
        return (data, mime)


'''

# 插入压缩函数
lines.insert(insert_line, compress_func)

# 修改 _fetch_profile_image_from_oss 函数，在返回前调用压缩
for i in range(insert_line + 1, min(insert_line + 100, len(lines))):
    if 'return (data, mime)' in lines[i] and '_fetch_profile_image_from_oss' in ''.join(lines[max(0, i-30):i]):
        indent = len(lines[i]) - len(lines[i].lstrip())
        lines[i] = ' ' * indent + '# 压缩图片以加快 Gemini API 处理\n'
        lines.insert(i + 1, ' ' * indent + 'return _compress_profile_image(data, mime, max_size_kb=300)\n')
        break

# 写回文件
with open('main.py', 'w', encoding='utf-8') as f:
    f.writelines(lines)

print('✅ 已添加图片压缩功能')
