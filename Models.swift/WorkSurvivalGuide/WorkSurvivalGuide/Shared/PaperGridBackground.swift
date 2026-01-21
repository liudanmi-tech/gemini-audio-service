//
//  PaperGridBackground.swift
//  WorkSurvivalGuide
//
//  信纸网格底纹背景组件
//

import SwiftUI

struct PaperGridShape: Shape {
    var gridSize: CGFloat = 16 // 网格大小 16px
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 绘制垂直线
        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += gridSize
        }
        
        // 绘制水平线
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += gridSize
        }
        
        return path
    }
}

struct PaperGridBackground: View {
    var gridSize: CGFloat = 16 // 网格大小 16px
    var lineWidth: CGFloat = 1 // 线条粗细 1px
    var lineColor: Color = AppColors.gridLine
    
    var body: some View {
        PaperGridShape(gridSize: gridSize)
            .stroke(lineColor, lineWidth: lineWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PaperGridBackground()
        .background(AppColors.background)
        .frame(width: 300, height: 400)
}
