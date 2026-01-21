//
//  QuotationMarkView.swift
//  WorkSurvivalGuide
//
//  引号视图组件 - 根据 Figma 设计稿实现
//

import SwiftUI
import UIKit

struct QuotationMarkView: View {
    var size: CGFloat = 23.99 // 根据 Figma: 23.99 x 23.99
    var color: Color = AppColors.statusText
    var opacity: Double = 0.637
    var isGrayStyle: Bool = false // 是否为灰色引号样式（用于已完成状态）
    
    // 判断是否为灰色引号
    private var isGrayQuotation: Bool {
        return isGrayStyle
    }
    
    var body: some View {
        // 灰色引号和分析中状态的引号使用完全相同的样式，只是颜色不同
        // 使用 SVG 图片（如果可用），否则使用自定义形状
        if let image = UIImage(named: "QuotationMark") {
            // 使用 SVG 图片（适用于所有状态，包括灰色和橙色）
            Image(uiImage: image)
                .renderingMode(.template)
                .foregroundColor(color)
                .frame(width: size, height: size)
                .opacity(opacity) // 保持和分析中状态相同的透明度
        } else {
            // 备用方案：使用自定义形状
            // 样式一致：fill color.opacity(0.1), stroke color.opacity(0.5), lineWidth: 2
            HStack(spacing: 0) {
                // 左引号
                QuotationMarkShape(isLeft: true)
                    .fill(color.opacity(0.1))
                    .overlay(
                        QuotationMarkShape(isLeft: true)
                            .stroke(color.opacity(0.5), lineWidth: 2)
                    )
                
                // 右引号
                QuotationMarkShape(isLeft: false)
                    .fill(color.opacity(0.1))
                    .overlay(
                        QuotationMarkShape(isLeft: false)
                            .stroke(color.opacity(0.5), lineWidth: 2)
                    )
            }
            .frame(width: size, height: size)
            .opacity(opacity) // 保持和分析中状态相同的透明度
        }
    }
}

// 单个引号形状（根据 SVG 路径简化）
struct QuotationMarkShape: Shape {
    var isLeft: Bool = true
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width / 2
        let height = rect.height
        let x = isLeft ? rect.minX : rect.midX
        let y = rect.minY
        
        // 根据 SVG 路径简化绘制引号
        // 左引号路径: M5 2.99999... 或右引号路径: M16 2.99999...
        if isLeft {
            // 左引号
            path.move(to: CGPoint(x: x + width * 0.21, y: y + height * 0.125))
            path.addCurve(
                to: CGPoint(x: x + width * 0.125, y: y + height * 0.167),
                control1: CGPoint(x: x + width * 0.136, y: y + height * 0.125),
                control2: CGPoint(x: x + width * 0.125, y: y + height * 0.136)
            )
            path.addLine(to: CGPoint(x: x + width * 0.125, y: y + height * 0.458))
            path.addCurve(
                to: CGPoint(x: x + width * 0.21, y: y + height * 0.542),
                control1: CGPoint(x: x + width * 0.125, y: y + height * 0.511),
                control2: CGPoint(x: x + width * 0.136, y: y + height * 0.542)
            )
            path.addCurve(
                to: CGPoint(x: x + width * 0.25, y: y + height * 0.542),
                control1: CGPoint(x: x + width * 0.227, y: y + height * 0.542),
                control2: CGPoint(x: x + width * 0.239, y: y + height * 0.542)
            )
            path.addLine(to: CGPoint(x: x + width * 0.25, y: y + height * 0.625))
            path.addCurve(
                to: CGPoint(x: x + width * 0.167, y: y + height * 0.708),
                control1: CGPoint(x: x + width * 0.195, y: y + height * 0.625),
                control2: CGPoint(x: x + width * 0.167, y: y + height * 0.653)
            )
            path.addCurve(
                to: CGPoint(x: x + width * 0.125, y: y + height * 0.75),
                control1: CGPoint(x: x + width * 0.156, y: y + height * 0.708),
                control2: CGPoint(x: x + width * 0.146, y: y + height * 0.719)
            )
            path.addLine(to: CGPoint(x: x + width * 0.125, y: y + height * 0.833))
            path.addCurve(
                to: CGPoint(x: x + width * 0.167, y: y + height * 0.875),
                control1: CGPoint(x: x + width * 0.156, y: y + height * 0.833),
                control2: CGPoint(x: x + width * 0.146, y: y + height * 0.833)
            )
            path.addCurve(
                to: CGPoint(x: x + width * 0.417, y: y + height * 0.625),
                control1: CGPoint(x: x + width * 0.234, y: y + height * 0.875),
                control2: CGPoint(x: x + width * 0.417, y: y + height * 0.691)
            )
            path.addLine(to: CGPoint(x: x + width * 0.417, y: y + height * 0.208))
            path.addCurve(
                to: CGPoint(x: x + width * 0.333, y: y + height * 0.125),
                control1: CGPoint(x: x + width * 0.417, y: y + height * 0.136),
                control2: CGPoint(x: x + width * 0.395, y: y + height * 0.125)
            )
            path.closeSubpath()
        } else {
            // 右引号（镜像左引号）
            path.move(to: CGPoint(x: x + width * 0.79, y: y + height * 0.125))
            path.addCurve(
                to: CGPoint(x: x + width * 0.875, y: y + height * 0.167),
                control1: CGPoint(x: x + width * 0.864, y: y + height * 0.125),
                control2: CGPoint(x: x + width * 0.875, y: y + height * 0.136)
            )
            path.addLine(to: CGPoint(x: x + width * 0.875, y: y + height * 0.458))
            path.addCurve(
                to: CGPoint(x: x + width * 0.79, y: y + height * 0.542),
                control1: CGPoint(x: x + width * 0.875, y: y + height * 0.511),
                control2: CGPoint(x: x + width * 0.864, y: y + height * 0.542)
            )
            path.addCurve(
                to: CGPoint(x: x + width * 0.75, y: y + height * 0.542),
                control1: CGPoint(x: x + width * 0.773, y: y + height * 0.542),
                control2: CGPoint(x: x + width * 0.761, y: y + height * 0.542)
            )
            path.addLine(to: CGPoint(x: x + width * 0.75, y: y + height * 0.625))
            path.addCurve(
                to: CGPoint(x: x + width * 0.833, y: y + height * 0.708),
                control1: CGPoint(x: x + width * 0.805, y: y + height * 0.625),
                control2: CGPoint(x: x + width * 0.833, y: y + height * 0.653)
            )
            path.addCurve(
                to: CGPoint(x: x + width * 0.875, y: y + height * 0.75),
                control1: CGPoint(x: x + width * 0.844, y: y + height * 0.708),
                control2: CGPoint(x: x + width * 0.854, y: y + height * 0.719)
            )
            path.addLine(to: CGPoint(x: x + width * 0.875, y: y + height * 0.833))
            path.addCurve(
                to: CGPoint(x: x + width * 0.833, y: y + height * 0.875),
                control1: CGPoint(x: x + width * 0.844, y: y + height * 0.833),
                control2: CGPoint(x: x + width * 0.854, y: y + height * 0.833)
            )
            path.addCurve(
                to: CGPoint(x: x + width * 0.583, y: y + height * 0.625),
                control1: CGPoint(x: x + width * 0.766, y: y + height * 0.875),
                control2: CGPoint(x: x + width * 0.583, y: y + height * 0.691)
            )
            path.addLine(to: CGPoint(x: x + width * 0.583, y: y + height * 0.208))
            path.addCurve(
                to: CGPoint(x: x + width * 0.667, y: y + height * 0.125),
                control1: CGPoint(x: x + width * 0.583, y: y + height * 0.136),
                control2: CGPoint(x: x + width * 0.605, y: y + height * 0.125)
            )
            path.closeSubpath()
        }
        
        return path
    }
}

#Preview {
    QuotationMarkView()
        .padding()
        .background(Color.white)
}
