//
//  SkillUnlockEffect.swift
//  WorkSurvivalGuide
//
//  AirDrop 风格技能解锁特效：三层涟漪扩散 + 4芒星旋转 + 顶部 Toast
//

import SwiftUI
import UIKit

// MARK: - Public overlay view

/// 将此视图叠加在任何内容上方。isShowing 为 true 时开始播放，动画结束后自动设为 false。
/// skillName: 要在 Toast 中显示的技能名称
/// origin:    涟漪中心点（view 本地坐标）；传 nil 则使用视图几何中心
struct SkillUnlockEffect: View {
    @Binding var isShowing: Bool
    let skillName: String
    var origin: CGPoint? = nil

    // ── Ripple ring flags (each flag adds a ring to the ZStack) ─────────────
    @State private var ring1On = false
    @State private var ring2On = false
    @State private var ring3On = false

    // ── Central spinning star ────────────────────────────────────────────────
    @State private var starAngle: Double  = 0
    @State private var starScale: CGFloat = 1.0

    // ── Top toast ────────────────────────────────────────────────────────────
    @State private var toastOffset:  CGFloat = -72
    @State private var toastOpacity: Double  = 0

    // ── Body ─────────────────────────────────────────────────────────────────

    var body: some View {
        GeometryReader { geo in
            let centre = origin ?? CGPoint(x: geo.size.width / 2,
                                           y: geo.size.height / 2)
            ZStack {
                // ── 1. Ripple rings (added to hierarchy only when flagged) ───
                if ring1On {
                    RippleRing(color: Color(hex: "#00D4FF"))
                        .position(centre)
                }
                if ring2On {
                    RippleRing(color: Color(hex: "#00D4FF"))
                        .position(centre)
                }
                if ring3On {
                    RippleRing(color: Color(hex: "#00D4FF"))
                        .position(centre)
                }

                // ── 2. Spinning 4-point star at ripple origin ────────────────
                SpinningStarView(angle: starAngle, scale: starScale)
                    .position(centre)

                // ── 3. Top toast ─────────────────────────────────────────────
                VStack {
                    toastBanner
                        .offset(y: toastOffset)
                        .opacity(toastOpacity)
                    Spacer()
                }
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .allowsHitTesting(false)
        .task { await runSequence() }
    }

    // ── Animation sequence ───────────────────────────────────────────────────

    @MainActor
    private func runSequence() async {
        // t = 0.0 s ── Ring 1 + haptic + star begins spinning ────────────────
        ring1On = true
        haptic(.medium)
        withAnimation(.linear(duration: 0.8)) {
            starAngle = 360
        }
        withAnimation(.easeOut(duration: 0.40)) {
            starScale = 2.5
        }

        try? await Task.sleep(nanoseconds: 300_000_000) // +0.3 s

        // t = 0.3 s ── Ring 2 + haptic ────────────────────────────────────────
        ring2On = true
        haptic(.medium)

        try? await Task.sleep(nanoseconds: 200_000_000) // +0.2 s = 0.5 s total

        // t = 0.5 s ── Toast slides in ────────────────────────────────────────
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            toastOffset  = 0
            toastOpacity = 1
        }

        try? await Task.sleep(nanoseconds: 100_000_000) // +0.1 s = 0.6 s total

        // t = 0.6 s ── Ring 3 + haptic + star scale back ───────────────────────
        ring3On = true
        haptic(.medium)
        withAnimation(.easeIn(duration: 0.36)) {
            starScale = 1.2
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000) // +2.0 s = 2.6 s total

        // t = 2.6 s ── Toast slides out ───────────────────────────────────────
        withAnimation(.easeIn(duration: 0.30)) {
            toastOffset  = -72
            toastOpacity = 0
        }

        try? await Task.sleep(nanoseconds: 600_000_000) // +0.6 s = 3.2 s total

        // Dismiss
        isShowing = false
    }

    // ── Toast banner ─────────────────────────────────────────────────────────

    private var toastBanner: some View {
        HStack(spacing: 6) {
            Text("✦")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "#00D4FF"))
            Text("\(skillName) Unlocked")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color(hex: "#00D4FF").opacity(0.32), lineWidth: 0.8)
        )
        .shadow(color: Color(hex: "#00D4FF").opacity(0.22), radius: 14, y: 4)
    }

    // ── Haptic helper ─────────────────────────────────────────────────────────

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Ripple ring

/// 每个 RippleRing 在出现（onAppear）时立即开始扩散动画。
/// 通过在父层按需加入 ZStack 实现各圈的时序延迟。
private struct RippleRing: View {
    let color: Color

    @State private var diameter:    CGFloat = 20
    @State private var lineOpacity: Double  = 0.8
    @State private var lineWidth:   CGFloat = 3.0

    var body: some View {
        Circle()
            .stroke(color.opacity(lineOpacity), lineWidth: lineWidth)
            .frame(width: diameter, height: diameter)
            .onAppear {
                // 直接在 onAppear（主线程）中启动动画
                withAnimation(.easeOut(duration: 1.5)) {
                    diameter    = 300
                    lineOpacity = 0
                    lineWidth   = 0.5
                }
            }
    }
}

// MARK: - Spinning 4-point star

private struct SpinningStarView: View {
    let angle: Double
    let scale: CGFloat

    var body: some View {
        ZStack {
            // Outer cyan halo
            Circle()
                .fill(Color(hex: "#00D4FF"))
                .frame(width: 38, height: 38)
                .blur(radius: 11)
                .opacity(0.48)

            // Inner bright ring
            Circle()
                .fill(Color(hex: "#00D4FF"))
                .frame(width: 16, height: 16)
                .blur(radius: 4)
                .opacity(0.62)

            // White core
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)

            // 4-point star spikes via Canvas
            Canvas { ctx, sz in
                let cx = sz.width / 2
                let cy = sz.height / 2

                var v = Path()
                v.move(to: CGPoint(x: cx, y: cy - 15))
                v.addLine(to: CGPoint(x: cx, y: cy + 15))

                var h = Path()
                h.move(to: CGPoint(x: cx - 9, y: cy))
                h.addLine(to: CGPoint(x: cx + 9, y: cy))

                ctx.stroke(v, with: .color(.white.opacity(0.90)), lineWidth: 0.9)
                ctx.stroke(h, with: .color(.white.opacity(0.72)), lineWidth: 0.9)
            }
            .frame(width: 42, height: 42)
        }
        .rotationEffect(.degrees(angle))
        .scaleEffect(scale)
    }
}
