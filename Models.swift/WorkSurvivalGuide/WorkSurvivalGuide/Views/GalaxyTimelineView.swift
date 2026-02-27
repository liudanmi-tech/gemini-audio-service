//
//  GalaxyTimelineView.swift
//  WorkSurvivalGuide
//
//  Recent task events — premium multi-layer glow nodes on a curved path
//

import SwiftUI

struct GalaxyTimelineView: View {
    let tasks: [TaskItem]

    // Pulse drives the repeating glow animation on every node
    @State private var pulse = false

    // ── Data logic (unchanged) ──────────────────────────────────────────────

    private var recentTasks: [TaskItem] {
        Array(
            tasks
                .filter { $0.status == .archived }
                .sorted { $0.startTime > $1.startTime }
                .prefix(3)
        )
    }

    // ── Body ────────────────────────────────────────────────────────────────

    var body: some View {
        if recentTasks.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.2))
                Text("录音后将在这里出现星迹")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.2))
            }
            .frame(height: 68)
            .frame(maxWidth: .infinity)
        } else {
            GeometryReader { geo in
                ZStack {
                    // Curved dashed path
                    curvePath(in: geo.size)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#00D4FF").opacity(0.04),
                                    Color(hex: "#00D4FF").opacity(0.20),
                                    Color(hex: "#00D4FF").opacity(0.04),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [3, 5])
                        )

                    // Premium glowing task nodes
                    ForEach(Array(recentTasks.enumerated()), id: \.offset) { i, task in
                        taskNode(task: task)
                            .position(nodePos(index: i, total: recentTasks.count, size: geo.size))
                    }
                }
            }
            .frame(height: 68)
            .onAppear { pulse = true }
        }
    }

    // ── Curved path (unchanged) ─────────────────────────────────────────────

    private func curvePath(in size: CGSize) -> Path {
        Path { p in
            let h = size.height
            p.move(to: CGPoint(x: 16, y: h * 0.62))
            p.addCurve(
                to: CGPoint(x: size.width - 16, y: h * 0.38),
                control1: CGPoint(x: size.width * 0.33, y: h * 0.18),
                control2: CGPoint(x: size.width * 0.66, y: h * 0.78)
            )
        }
    }

    // ── Node position along the curve (unchanged) ───────────────────────────

    private func nodePos(index: Int, total: Int, size: CGSize) -> CGPoint {
        let xFracs: [CGFloat]
        let yFracs: [CGFloat]
        switch total {
        case 1:  xFracs = [0.50];        yFracs = [0.50]
        case 2:  xFracs = [0.28, 0.72];  yFracs = [0.54, 0.44]
        default: xFracs = [0.18, 0.50, 0.82]; yFracs = [0.58, 0.48, 0.40]
        }
        let x = (index < xFracs.count ? xFracs[index] : 0.5) * size.width
        let y = (index < yFracs.count ? yFracs[index] : 0.5) * size.height
        return CGPoint(x: x, y: y)
    }

    // ── Premium node — gold/amber, multi-layer glow + spike + pulse ─────────

    @ViewBuilder
    private func taskNode(task: TaskItem) -> some View {
        let amber = Color(hex: "#F9B233")

        VStack(spacing: 3) {
            ZStack {
                // Layer 1: Large blur halo — 40pt, pulsing 0.08 ↔ 0.22 opacity
                Circle()
                    .fill(amber)
                    .frame(width: 40, height: 40)
                    .blur(radius: 12)
                    .opacity(pulse ? 0.22 : 0.08)
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: pulse
                    )

                // Layer 2: Medium glow — 20pt, pulsing 0.25 ↔ 0.55 opacity
                Circle()
                    .fill(amber)
                    .frame(width: 20, height: 20)
                    .blur(radius: 4)
                    .opacity(pulse ? 0.55 : 0.25)
                    .animation(
                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: pulse
                    )

                // Layer 3: Bright core — 6pt white center, full opacity
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)

                // Layer 4: 4-point star spike via Canvas
                Canvas { ctx, size in
                    let cx = size.width  / 2
                    let cy = size.height / 2

                    var vPath = Path()
                    vPath.move(to: CGPoint(x: cx, y: cy - 10))
                    vPath.addLine(to: CGPoint(x: cx, y: cy + 10))

                    var hPath = Path()
                    hPath.move(to: CGPoint(x: cx - 6, y: cy))
                    hPath.addLine(to: CGPoint(x: cx + 6, y: cy))

                    ctx.stroke(vPath, with: .color(.white.opacity(0.80)), lineWidth: 0.8)
                    ctx.stroke(hPath, with: .color(.white.opacity(0.60)), lineWidth: 0.8)
                }
                .frame(width: 28, height: 28)
            }

            Text(shortTitle(task))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
                .fixedSize()
        }
    }

    // ── Helpers (unchanged) ─────────────────────────────────────────────────

    private func shortTitle(_ task: TaskItem) -> String {
        let t = task.refinedTitle
        guard t.count > 6 else { return t }
        let end = t.index(t.startIndex, offsetBy: 5)
        return String(t[..<end]) + "…"
    }
}
