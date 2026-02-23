//
//  ImageStyle.swift
//  WorkSurvivalGuide
//
//  图片风格模型与 14 种风格数据，用于策略图片生成
//

import SwiftUI

struct ImageStyle: Identifiable {
    let id: String
    let name: String
    let nameEn: String
    let promptKeywords: String
    /// 占位示例块主色（用于风格选择弹窗）
    let accentColor: Color
}

/// 14 种图片风格 + 默认宫崎骏
enum ImageStylePresets {
    static let ghibli = ImageStyle(
        id: "ghibli",
        name: "宫崎骏风格",
        nameEn: "Ghibli",
        promptKeywords: "宫崎骏吉卜力动画风格：温暖自然色调、柔和手绘笔触、细腻光影、治愈系氛围。类似《龙猫》《千与千寻》的质感与色彩。",
        accentColor: Color(hex: "#7CBC6C")
    )
    
    static let all: [ImageStyle] = [
        ghibli,
        ImageStyle(id: "shinkai", name: "新海诚风格", nameEn: "Makoto Shinkai",
                   promptKeywords: "新海诚动画风格：高饱和蓝天、体积云与光线穿透、水面与玻璃反光、铁路与城镇。《你的名字》《天气之子》式的浪漫唯美画面。",
                   accentColor: Color(hex: "#4A90D9")),
        ImageStyle(id: "pixar", name: "皮克斯风格", nameEn: "Pixar 3D",
                   promptKeywords: "皮克斯 3D 动画风格：圆润角色建模、柔和体积光、细腻 PBR 材质、情感化表情。类似《寻梦环游记》《心灵奇旅》的照明与质感。",
                   accentColor: Color(hex: "#E8A838")),
        ImageStyle(id: "cyberpunk", name: "赛博朋克风", nameEn: "Cyberpunk",
                   promptKeywords: "《赛博朋克2077》夜之城风格：主色调霓虹黄与青蓝，高对比暗部与霓虹高光。雨夜街道、霓虹招牌、义体与全息投影。脏乱与光鲜并存，电影级光影。",
                   accentColor: Color(hex: "#FF00FF")),
        ImageStyle(id: "watercolor", name: "水彩插画风", nameEn: "Watercolor illustration",
                   promptKeywords: "水彩插画风格：晕染边缘、透明叠色、留白与纸纹、清新自然。类似儿童绘本或插画集的水彩质感。",
                   accentColor: Color(hex: "#87CEEB")),
        ImageStyle(id: "ukiyoe", name: "浮世绘风格", nameEn: "Ukiyo-e",
                   promptKeywords: "日式浮世绘风格：平面构图、黑色勾线描边、传统配色（靛蓝、朱红、浅绿）。葛饰北斋或歌川广重的经典浮世绘美感。",
                   accentColor: Color(hex: "#2E5090")),
        ImageStyle(id: "line_art", name: "黑白线稿风", nameEn: "Minimalist line art",
                   promptKeywords: "极简黑白线稿风格：纯黑白、细线条勾勒、大量留白、极少阴影。类似漫画分镜或手绘草图。",
                   accentColor: Color(hex: "#333333")),
        ImageStyle(id: "steampunk", name: "蒸汽朋克风", nameEn: "Steampunk",
                   promptKeywords: "蒸汽朋克风格：铜黄机械、齿轮管道、维多利亚时代服饰、复古工业美学。蒸汽机、飞艇与齿轮的复古科幻感。",
                   accentColor: Color(hex: "#B8860B")),
        ImageStyle(id: "pop_art", name: "波普艺术风", nameEn: "Pop Art",
                   promptKeywords: "波普艺术风格：粗黑轮廓线、高饱和纯色块、网点纹理、强对比。类似安迪·沃霍尔或 Roy Lichtenstein 的波普美感。",
                   accentColor: Color(hex: "#FF4500")),
        ImageStyle(id: "scandinavian", name: "北欧插画风", nameEn: "Scandinavian illustration",
                   promptKeywords: "北欧插画风格：扁平色块、低饱和度、几何简约、温馨治愈。斯堪的纳维亚绘本的柔和与克制。",
                   accentColor: Color(hex: "#98D8AA")),
        ImageStyle(id: "retro_manga", name: "复古昭和漫画", nameEn: "Retro 80s manga",
                   promptKeywords: "昭和复古漫画风格：网点纸纹理、粗边框、怀旧暖色调。类似 80 年代日本漫画的网点与线条。",
                   accentColor: Color(hex: "#DAA520")),
        ImageStyle(id: "oil_painting", name: "油画质感", nameEn: "Oil painting",
                   promptKeywords: "古典油画风格：厚涂笔触、伦勃朗式明暗、暖色光感、画布质感。类似伦勃朗或印象派的古典构图。",
                   accentColor: Color(hex: "#8B4513")),
        ImageStyle(id: "pixel", name: "像素风", nameEn: "Pixel art",
                   promptKeywords: "16-bit 像素风格：方色块、有限色板、HD-2D 景深。类似《八方旅人》的复古游戏质感。",
                   accentColor: Color(hex: "#9B59B6")),
        ImageStyle(id: "chinese_ink", name: "中国水墨风", nameEn: "Traditional Chinese ink",
                   promptKeywords: "中国水墨画风格：墨分五色（焦浓重淡清）、宣纸晕染、大量留白、写意笔触。传统山水或人物水墨的淡雅诗意。",
                   accentColor: Color(hex: "#4A4A4A")),
        ImageStyle(id: "storybook", name: "童话绘本风", nameEn: "Storybook illustration",
                   promptKeywords: "欧洲童话绘本风格：柔和水彩、复古装帧感、梦幻氛围。类似《小王子》插图的温馨与幻想。",
                   accentColor: Color(hex: "#DDA0DD"))
    ]
    
    static func byId(_ id: String) -> ImageStyle? {
        all.first { $0.id == id }
    }
}
