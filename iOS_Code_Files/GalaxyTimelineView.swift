//
//  GalaxyTimelineView.swift
//  WorkSurvivalGuide
//
//  银河丝带时间轴：三层发光 S 曲线 + 4芒星节点 + 毛玻璃事件标签
//

import SwiftUI

struct GalaxyTimelineView: View {
    let tasks: [TaskItem]

    @State private var pulse = false

    // ── Data (interface unchanged) ───────────────────────────────────────────

    private var recentTasks: [TaskItem] {
        Array(
            tasks
                .filter { $0.status == .archived }
                .sorted { $0.startTime > $1.startTime }
                .prefix(3)
        )
    }

    // ── Layout constants ─────────────────────────────────────────────────────

    private let viewHeight: CGFloat = 140
    /// Bezier t parameters for the 3 node positions along the ribbon
    private let tValues: [CGFloat] = [0.18, 0.50, 0.82]
    /// +1 → CW perpendicular (above-left of travel direction)
    /// -1 → CCW perpendicular (below-right of travel direction)
    private let nodeSides: [CGFloat] = [1, -1, 1]
    /// How far each node sits from the ribbon centre-line
    private let nodeOffsetDist: CGFloat = 20
    /// How far the label centre sits from the node centre (same perpendicular dir)
    private let labelOffsetDist: CGFloat = 34

    // ── Nested curve helper ───────────────────────────────────────────────────

    private struct Curve {
        let p0, cp1, cp2, p3: CGPoint

        var path: Path {
            Path { p in
                p.move(to: p0)
                p.addCurve(to: p3, control1: cp1, control2: cp2)
            }
        }

        func point(at t: CGFloat) -> CGPoint {
            let mt = 1 - t
            return CGPoint(
                x: mt*mt*mt*p0.x + 3*mt*mt*t*cp1.x + 3*mt*t*t*cp2.x + t*t*t*p3.x,
                y: mt*mt*mt*p0.y + 3*mt*mt*t*cp1.y + 3*mt*t*t*cp2.y + t*t*t*p3.y
            )
        }

        /// Returns the unit tangent at parameter t
        func tangent(at t: CGFloat) -> CGPoint {
            let mt = 1 - t
            let dx = 3*mt*mt*(cp1.x-p0.x) + 6*mt*t*(cp2.x-cp1.x) + 3*t*t*(p3.x-cp2.x)
            let dy = 3*mt*mt*(cp1.y-p0.y) + 6*mt*t*(cp2.y-cp1.y) + 3*t*t*(p3.y-cp2.y)
            let len = sqrt(dx*dx + dy*dy)
            return len > 0 ? CGPoint(x: dx/len, y: dy/len) : CGPoint(x: 1, y: 0)
        }

        /// Perpendicular of unit tangent:
        ///   side = +1 → CW rotation → (ty, -tx)  (above-left for upward travel)
        ///   side = -1 → CCW rotation → (-ty, tx) (below-right)
        func perp(at t: CGFloat, side: CGFloat) -> CGPoint {
            let tang = tangent(at: t)
            return CGPoint(x: tang.y * side, y: -tang.x * side)
        }
    }

    private func makeCurve(in size: CGSize) -> Curve {
        let w = size.width, h = size.height
        // S-shape: starts bottom-left, curves up through centre, ends top-right
        return Curve(
            p0:  CGPoint(x: w * 0.04, y: h * 0.88),
            cp1: CGPoint(x: w * 0.22, y: h * 0.08),
            cp2: CGPoint(x: w * 0.78, y: h * 0.92),
            p3:  CGPoint(x: w * 0.96, y: h * 0.12)
        )
    }

    // ── Body ─────────────────────────────────────────────────────────────────

    var body: some View {
        if recentTasks.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.20))
                Text("Your timeline will appear here after your first recording")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.20))
            }
            .frame(height: viewHeight)
            .frame(maxWidth: .infinity)
        } else {
            GeometryReader { geo in
                let sz    = geo.size
                let curve = makeCurve(in: sz)
                let cyan  = Color(hex: "#00D4FF")

                ZStack {
                    // ── 1. Micro-star particles ────────────────────────────
                    Canvas { ctx, csz in
                        var seed: UInt64 = 24601
                        func rand() -> Double {
                            seed = seed &* 6364136223846793005 &+ 1442695040888963407
                            return Double(seed >> 33) / Double(UInt32.max)
                        }
                        for _ in 0..<45 {
                            let x  = rand() * Double(csz.width)
                            let y  = rand() * Double(csz.height)
                            let r  = rand() * 0.60 + 0.25
                            let op = rand() * 0.28 + 0.07
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)),
                                with: .color(.white.opacity(op))
                            )
                        }
                    }

                    // ── 2. Galaxy ribbon — outer glow (20 pt, opacity 0.08) ─
                    curve.path
                        .stroke(cyan.opacity(0.08), lineWidth: 20)

                    // ── 3. Galaxy ribbon — mid layer (10 pt, opacity 0.15) ──
                    curve.path
                        .stroke(cyan.opacity(0.15), lineWidth: 10)

                    // ── 4. Galaxy ribbon — inner bright line (2 pt, 0.60) ───
                    curve.path
                        .stroke(cyan.opacity(0.60), lineWidth: 2)

                    // ── 5. Nodes + labels ──────────────────────────────────
                    ForEach(Array(recentTasks.enumerated()), id: \.offset) { i, task in
                        let t    = tValues[i]
                        let side = nodeSides[i]
                        let cp   = curve.point(at: t)
                        let perp = curve.perp(at: t, side: side)

                        let nPos = CGPoint(
                            x: cp.x + perp.x * nodeOffsetDist,
                            y: cp.y + perp.y * nodeOffsetDist
                        )
                        // Label sits further along same perpendicular; clamped inside view
                        let rawLabel = CGPoint(
                            x: nPos.x + perp.x * labelOffsetDist,
                            y: nPos.y + perp.y * labelOffsetDist
                        )
                        let lPos = CGPoint(
                            x: max(52, min(sz.width - 52, rawLabel.x)),
                            y: max(22, min(sz.height - 22, rawLabel.y))
                        )

                        // Thin connector line
                        Path { path in
                            path.move(to: nPos)
                            path.addLine(to: lPos)
                        }
                        .stroke(cyan.opacity(0.30), lineWidth: 0.5)

                        // Star node
                        starNodeView(index: i)
                            .position(nPos)

                        // Frosted-glass event label
                        eventLabelView(task: task)
                            .position(lPos)
                    }
                }
            }
            .frame(height: viewHeight)
            .onAppear { pulse = true }
        }
    }

    // ── 4-point star node ────────────────────────────────────────────────────

    @ViewBuilder
    private func starNodeView(index: Int) -> some View {
        let isMain = index == 0
        let haloD: CGFloat = isMain ? 36 : (index == 1 ? 26 : 18)
        let coreD: CGFloat = isMain ? 8  : (index == 1 ? 6  : 5)
        let vLen:  CGFloat = isMain ? 13 : (index == 1 ? 9  : 7)
        let hLen:  CGFloat = isMain ? 8  : (index == 1 ? 6  : 4)
        let cyan = Color(hex: "#00D4FF")

        ZStack {
            // Outer halo — pulsing animation on the most important node
            Circle()
                .fill(cyan)
                .frame(width: haloD, height: haloD)
                .blur(radius: haloD / 2.8)
                .opacity(isMain ? (pulse ? 0.55 : 0.18) : 0.25)
                .animation(
                    isMain
                        ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                        : .none,
                    value: pulse
                )

            // Inner bright ring
            Circle()
                .fill(cyan)
                .frame(width: haloD * 0.42, height: haloD * 0.42)
                .blur(radius: 3)
                .opacity(0.40)

            // White core
            Circle()
                .fill(Color.white)
                .frame(width: coreD, height: coreD)

            // 4-point star spikes
            Canvas { ctx, sz in
                let cx = sz.width / 2
                let cy = sz.height / 2
                var v = Path()
                v.move(to: CGPoint(x: cx, y: cy - vLen))
                v.addLine(to: CGPoint(x: cx, y: cy + vLen))
                var h = Path()
                h.move(to: CGPoint(x: cx - hLen, y: cy))
                h.addLine(to: CGPoint(x: cx + hLen, y: cy))
                ctx.stroke(v, with: .color(.white.opacity(0.88)), lineWidth: 0.8)
                ctx.stroke(h, with: .color(.white.opacity(0.68)), lineWidth: 0.8)
            }
            .frame(width: 34, height: 34)
        }
    }

    // ── Frosted-glass event label ─────────────────────────────────────────────

    @ViewBuilder
    private func eventLabelView(task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(shortDate(task.startTime))
                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#00D4FF").opacity(0.85))
            Text(task.refinedTitle)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.90))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 88, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "#00D4FF").opacity(0.18), lineWidth: 0.5)
        )
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MM.dd"
        return fmt.string(from: date)
    }
}
