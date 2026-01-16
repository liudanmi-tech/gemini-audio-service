#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import sys

# 从命令行读取 JSON 或使用示例数据
if len(sys.argv) > 1:
    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        data = json.load(f)
else:
    # 示例数据（从用户的输出中提取）
    data = {
        "code": 200,
        "message": "success",
        "data": {
            "visual": [
                {
                    "transcript_index": 0,
                    "speaker": "Speaker_0",
                    "image_prompt": "\u7c73\u8272\u80cc\u666f\uff0c\u6781\u7b80\u706b\u67f4\u4eba\u7ebf\u7a3f\u3002\u5de6\u4fa7\u4e3a\u7528\u6237\uff08Speaker_1\uff09\uff0c\u6807\u6ce8'\u6211'\uff0c\u53cc\u81c2\u81ea\u7136\u4e0b\u5782\u4f46\u62f3\u5934\u5fae\u5fae\u63e1\u7d27\uff0c\u8eab\u4f53\u4e2d\u7acb\uff0c\u8868\u73b0\u51fa\u793c\u8c8c\u6027\u7684\u503e\u542c\u3002\u53f3\u4fa7\u4e3a\u5bf9\u65b9\uff08Speaker_0\uff09\uff0c\u6807\u6ce8'\u5bf9\u65b9'\uff0c\u4e0a\u534a\u8eab\u5927\u5e45\u5ea6\u524d\u503e\uff0c\u53f3\u624b\u6307\u5411\u5de6\u4fa7\uff0c\u505a\u51fa\u2018\u4e0b\u8fbe\u6307\u4ee4\u2019\u7684\u59ff\u6001\u3002\u573a\u666f\u63cf\u8ff0\uff1a\u5178\u578b\u7684\u9700\u6c42\u2018\u52a0\u585e\u2019\u65f6\u523b\uff0c\u5bf9\u65b9\u5229\u7528\u804c\u6743\u9ad8\u5ea6\u5360\u636e\u7a7a\u95f4\uff0c\u8bd5\u56fe\u5728\u6c14\u52bf\u4e0a\u8986\u76d6\u7528\u6237\u3002",
                    "emotion": "\u65bd\u538b\u3001\u638c\u63a7",
                    "subtext": "\u8fd9\u4ef6\u4e8b\u6ca1\u5f97\u5546\u91cf\uff0c\u4f60\u5fc5\u987b\u63a5\u53d7\u3002",
                    "context": "\u5bf9\u65b9\u5728\u672a\u6c9f\u901a\u8fdb\u5ea6\u7684\u60c5\u51b5\u4e0b\u7a81\u7136\u589e\u52a0\u9ad8\u5f3a\u5ea6\u4efb\u52a1\uff0c\u6d4b\u8bd5\u7528\u6237\u7684\u5e95\u7ebf\u3002",
                    "my_inner": "\u53c8\u6765\u8fd9\u4e00\u5957\uff0c\u5b8c\u5168\u4e0d\u8003\u8651\u6211\u624b\u5934\u7684\u4f18\u5148\u7ea7\u3002",
                    "other_inner": "\u5148\u538b\u4e0b\u53bb\uff0c\u770b\u4ed6\u6562\u4e0d\u6562\u53cd\u6297\uff0c\u53cd\u6b63\u6700\u540e\u5f97\u6709\u4eba\u5e72\u3002"
                }
            ]
        }
    }

print("=" * 80)
print("解码并检查 image_prompt")
print("=" * 80)
print()

if data.get('code') == 200:
    visual_list = data.get('data', {}).get('visual', [])
    
    print(f"✅ 关键时刻数量: {len(visual_list)}")
    print()
    
    # 检查项
    required_elements = {
        "说话人位置和身份标注": False,
        "情绪表现（肢体语言、表情、姿态）": False,
        "潜台词暗示（细微动作）": False,
        "情景描述": False
    }
    
    for i, v in enumerate(visual_list):
        print(f"{'=' * 80}")
        print(f"关键时刻 {i+1}")
        print(f"{'=' * 80}")
        print(f"transcript_index: {v.get('transcript_index')}")
        print(f"speaker: {v.get('speaker')}")
        print(f"emotion: {v.get('emotion')}")
        print(f"subtext: {v.get('subtext')}")
        print(f"context: {v.get('context')}")
        print(f"my_inner: {v.get('my_inner')}")
        print(f"other_inner: {v.get('other_inner')}")
        print()
        
        # 解码 image_prompt
        image_prompt = v.get('image_prompt', '')
        print("image_prompt (解码后):")
        print("-" * 80)
        print(image_prompt)
        print("-" * 80)
        print()
        
        # 检查是否包含必需元素
        print("检查 image_prompt 是否包含必需元素:")
        print("-" * 80)
        
        # 1. 说话人位置和身份标注
        if "左侧" in image_prompt and "右侧" in image_prompt and ("用户" in image_prompt or "Speaker" in image_prompt):
            required_elements["说话人位置和身份标注"] = True
            print("✅ 说话人位置和身份标注: 包含")
        else:
            print("❌ 说话人位置和身份标注: 缺失")
        
        # 2. 情绪表现
        emotion_keywords = ["身体", "表情", "姿态", "动作", "前倾", "后仰", "交叉", "指向", "叉腰", "托住", "扶", "视线"]
        if any(keyword in image_prompt for keyword in emotion_keywords):
            required_elements["情绪表现（肢体语言、表情、姿态）"] = True
            print("✅ 情绪表现（肢体语言、表情、姿态）: 包含")
        else:
            print("❌ 情绪表现（肢体语言、表情、姿态）: 缺失")
        
        # 3. 潜台词暗示
        subtext_keywords = ["暗示", "细微", "显示", "表现出", "展现出"]
        if any(keyword in image_prompt for keyword in subtext_keywords) or len([w for w in emotion_keywords if w in image_prompt]) >= 3:
            required_elements["潜台词暗示（细微动作）"] = True
            print("✅ 潜台词暗示（细微动作）: 包含")
        else:
            print("❌ 潜台词暗示（细微动作）: 缺失")
        
        # 4. 情景描述
        if "场景描述" in image_prompt or "场景" in image_prompt:
            required_elements["情景描述"] = True
            print("✅ 情景描述: 包含")
        else:
            print("❌ 情景描述: 缺失")
        
        print()
    
    print("=" * 80)
    print("总结")
    print("=" * 80)
    all_passed = all(required_elements.values())
    for element, passed in required_elements.items():
        status = "✅" if passed else "❌"
        print(f"{status} {element}")
    
    if all_passed:
        print()
        print("🎉 所有必需元素都已包含！image_prompt 符合要求！")
    else:
        print()
        print("⚠️  部分元素缺失，可能需要优化提示词")
else:
    print(f"❌ 错误: {data.get('message')}")
