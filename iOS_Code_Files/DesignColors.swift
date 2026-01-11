import SwiftUI

/// Figma设计稿的颜色配置
struct AppColors {
    // 背景色
    static let background = Color(hex: "#FDF6E3") // 米黄色背景
    static let cardBackground = Color(hex: "#FFFDF5") // 卡片背景
    
    // 文字颜色
    static let primaryText = Color(hex: "#2C3E50") // 主文字颜色
    static let secondaryText = Color(hex: "#6A7282") // 次文字颜色
    static let headerText = Color(hex: "#5E7C8B") // Header文字颜色
    
    // 边框和分割线
    static let border = Color(hex: "#5E7C8B") // 边框颜色
    static let divider = Color(hex: "#5E7C8B") // 分割线颜色
    
    // 状态颜色
    struct Status {
        static let analyzingBg = Color(hex: "#FEF9C2") // 分析中背景
        static let analyzingText = Color(hex: "#D08700") // 分析中文字
        static let analyzingBorder = Color(hex: "#FFF085") // 分析中边框
        static let completedBg = Color(hex: "#DCFCE7") // 已完成背景
        static let completedText = Color(hex: "#00A63E") // 已完成文字
        static let completedBorder = Color(hex: "#B9F8CF") // 已完成边框
    }
    
    // 标签颜色
    struct Tag {
        static let anxietyBg = Color(hex: "#E8D5C4") // 焦虑标签背景
        static let puaBg = Color(hex: "#FFF4BD") // PUA预警标签背景
        static let creativeBg = Color(hex: "#C4E8D1") // 创意标签背景
        static let tagText = Color(hex: "#5E7C8B") // 标签文字颜色
        static let tagBorder = Color(white: 0, opacity: 0.1) // 标签边框
    }
    
    // 按钮颜色
    static let recordButton = Color(hex: "#FF6B6B") // 录音按钮
    static let recordButtonBorder = Color.white // 录音按钮边框
    
    // 底部导航
    struct BottomNav {
        static let activeText = Color(hex: "#5E7C8B") // 激活文字
        static let inactiveText = Color(hex: "#5E7C8B").opacity(0.6) // 非激活文字
        static let activeIconBg = Color(hex: "#FFD59E") // 激活图标背景
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
