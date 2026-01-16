#!/bin/bash
# 验证图片 URL 是否可以访问

SESSION_ID="670a5864-22d2-4978-b996-bce22c61afc5"

echo "========== 验证图片 URL 访问 =========="
echo ""

echo "1. 直接访问 OSS URL..."
echo ""

for i in 0 1 2; do
    url="https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/${SESSION_ID}/${i}.png"
    echo "图片 ${i}:"
    echo "  URL: $url"
    
    # 检查 HTTP 状态码
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$status_code" = "200" ]; then
        echo "  ✅ 可访问 (HTTP $status_code)"
        
        # 获取文件大小
        content_length=$(curl -s -I "$url" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
        if [ -n "$content_length" ]; then
            size_kb=$((content_length / 1024))
            echo "  文件大小: ${size_kb} KB"
        fi
    else
        echo "  ❌ 无法访问 (HTTP $status_code)"
    fi
    echo ""
done

echo "2. 通过后端 API 访问图片..."
echo ""

for i in 0 1 2; do
    api_url="http://localhost:8001/api/v1/images/${SESSION_ID}/${i}"
    echo "图片 ${i}:"
    echo "  API URL: $api_url"
    
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$api_url")
    
    if [ "$status_code" = "200" ]; then
        echo "  ✅ 可访问 (HTTP $status_code)"
        
        # 获取文件大小
        content_length=$(curl -s -I "$api_url" | grep -i "content-length" | awk '{print $2}' | tr -d '\r')
        if [ -n "$content_length" ]; then
            size_kb=$((content_length / 1024))
            echo "  文件大小: ${size_kb} KB"
        fi
    else
        echo "  ❌ 无法访问 (HTTP $status_code)"
    fi
    echo ""
done

echo "========== 验证完成 =========="
echo ""
echo "如果所有 URL 都返回 200，说明图片访问正常"
echo "可以在浏览器中打开这些 URL 查看图片"
