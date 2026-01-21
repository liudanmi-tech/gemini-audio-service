import SwiftUI

/// Figma设计稿的字体配置
/// 注意：iOS系统默认没有Nunito字体，这里使用相似的系统字体作为替代
struct AppFonts {
    // 标题字体（Nunito 900, 24px）
    static let headerTitle = Font.system(size: 24, weight: .black, design: .rounded)
    
    // 卡片标题字体（Nunito 700, 18px）
    static let cardTitle = Font.system(size: 18, weight: .bold, design: .rounded)
    
    // 时间字体（Nunito 400, 14px）
    static let time = Font.system(size: 14, weight: .regular, design: .rounded)
    
    // 日期大号数字字体（Nunito 700, 35px）
    static let dateNumber = Font.system(size: 35, weight: .bold, design: .rounded)
    
    // 星期字体（Nunito 700, 14px）
    static let weekday = Font.system(size: 14, weight: .bold, design: .rounded)
    
    // 年月字体（Nunito 500, 12px）
    static let yearMonth = Font.system(size: 12, weight: .medium, design: .rounded)
    
    // 时间范围字体（Inter 700, 14px）
    static let timeRange = Font.system(size: 14, weight: .bold, design: .default)
    
    // 状态文字字体（Nunito 500, 18px）
    static let statusText = Font.system(size: 18, weight: .medium, design: .rounded)
    
    // 状态标签字体（Nunito 700, 12px）
    static let statusLabel = Font.system(size: 12, weight: .bold, design: .rounded)
    
    // 标签文字字体（Nunito 600, 12px）
    static let tagText = Font.system(size: 12, weight: .semibold, design: .rounded)
    
    // 底部导航字体（Nunito 700, 12px）
    static let bottomNav = Font.system(size: 12, weight: .bold, design: .rounded)
}
