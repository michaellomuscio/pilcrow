//  Chrome.swift
//  Shared interface parts, built on the Lomuscio Labs system.
//  The brand owns the chrome. None of this appears inside the page.

import SwiftUI

// MARK: - Labels

/// IBM Plex Mono, uppercase, tracked. Counts, timers, metadata.
struct Eyebrow: View {
    let text: String
    var tint: Color = LL.ink3
    var body: some View {
        Text(text.uppercased())
            .font(PilcrowFonts.monoF(9.5, .medium))
            .tracking(1.3)
            .foregroundStyle(tint)
    }
}

struct PanelHeader: View {
    let title: String
    var trailing: AnyView? = nil

    init(_ title: String) { self.title = title; self.trailing = nil }
    init<T: View>(_ title: String, @ViewBuilder trailing: () -> T) {
        self.title = title
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(spacing: 8) {
            Eyebrow(text: title)
            Spacer(minLength: 4)
            if let trailing { trailing }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Badges

struct Pill: View {
    let text: String
    var tint: Color = LL.accent
    var filled: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(PilcrowFonts.monoF(9, .medium))
            .tracking(0.9)
            .foregroundStyle(filled ? LL.onAccent : tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                Capsule().fill(filled ? tint : tint.opacity(0.14))
            )
            .fixedSize()
    }
}

struct StatusDot: View {
    let status: NodeStatus
    var body: some View {
        Circle().fill(status.tint).frame(width: 7, height: 7)
    }
}

// MARK: - Buttons

struct LLButtonStyle: ButtonStyle {
    enum Kind { case primary, accent, secondary, ghost }
    var kind: Kind = .secondary
    var compact = false
    /// A custom style has to read this itself — `.disabled()` only dims the
    /// stock styles, so without it a disabled button looks perfectly clickable.
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let p = configuration.isPressed
        return configuration.label
            .font(PilcrowFonts.headingF(compact ? 11.5 : 12.5, .semibold))
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 5 : 7)
            .foregroundStyle(fg)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(bg.opacity(p ? 0.78 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .opacity(isEnabled ? (p ? 0.9 : 1) : 0.38)
            .saturation(isEnabled ? 1 : 0)
    }

    private var fg: Color {
        switch kind {
        case .primary:   return LL.ground
        case .accent:    return LL.onAccent
        case .secondary: return LL.ink
        case .ghost:     return LL.ink2
        }
    }
    private var bg: Color {
        switch kind {
        case .primary:   return LL.ink
        case .accent:    return LL.accent
        case .secondary: return LL.surface
        case .ghost:     return .clear
        }
    }
    private var stroke: Color {
        switch kind {
        case .primary, .accent: return .clear
        case .secondary:        return LL.rule
        case .ghost:            return .clear
        }
    }
}

extension View {
    func llButton(_ kind: LLButtonStyle.Kind = .secondary, compact: Bool = false) -> some View {
        buttonStyle(LLButtonStyle(kind: kind, compact: compact))
    }
}

/// A small square icon button used throughout the rails.
struct IconButton: View {
    let symbol: String
    var help: String = ""
    var tint: Color = LL.ink2
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(hovering ? LL.accent : tint)
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hovering ? LL.accentSoft : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

// MARK: - Surfaces

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    var outlined = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(LL.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(outlined ? LL.ink : LL.rule, lineWidth: outlined ? 1.5 : 1)
            )
    }
}

struct Rule: View {
    var body: some View { Rectangle().fill(LL.rule).frame(height: 1) }
}

struct VRule: View {
    var body: some View { Rectangle().fill(LL.rule).frame(width: 1) }
}

// MARK: - Empty state

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(LL.ink3)
            Text(title)
                .font(PilcrowFonts.headingF(16, .bold))
                .foregroundStyle(LL.ink)
            Text(message)
                .font(PilcrowFonts.bodyF(12.5))
                .foregroundStyle(LL.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
            if let actionLabel, let action {
                Button(actionLabel, action: action).llButton(.accent).padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - Progress ring (the sprint timer)

struct ProgressRing: View {
    var progress: Double
    var size: CGFloat = 62
    var lineWidth: CGFloat = 5
    var tint: Color = LL.accent
    var track: Color = LL.rule

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: progress)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Charts
//
// FiveThirtyEight rules from the brand kit: horizontal gridlines only,
// no chart junk, label the insight rather than the axis.

struct BarRow: View {
    let label: String
    let value: Double
    let max: Double
    var caption: String = ""
    var tint: Color = LL.accent
    var labelWidth: CGFloat = 46
    var captionWidth: CGFloat = 44

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(PilcrowFonts.monoF(9.5))
                .foregroundStyle(LL.ink3)
                .frame(width: labelWidth, alignment: .trailing)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(LL.rule).frame(height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint)
                        .frame(width: max > 0 ? geo.size.width * (value / max) : 0, height: 8)
                }
                .frame(height: geo.size.height, alignment: .center)
            }
            .frame(height: 12)
            if !caption.isEmpty {
                Text(caption)
                    .font(PilcrowFonts.monoF(9.5))
                    .foregroundStyle(LL.ink3)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: captionWidth, alignment: .leading)
            }
        }
    }
}

/// A compact sequence bar — scene lengths, session history, thread coverage.
struct Sparkbars: View {
    let values: [Double]
    var tint: Color = LL.accent
    var height: CGFloat = 34
    var highlightLast = true

    var body: some View {
        GeometryReader { geo in
            let maxV = values.max() ?? 1
            let n = Swift.max(1, values.count)
            let gap: CGFloat = n > 60 ? 0.5 : 2
            let w = Swift.max(1, (geo.size.width - gap * CGFloat(n - 1)) / CGFloat(n))
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(highlightLast && i == values.count - 1 ? tint : tint.opacity(0.45))
                        .frame(width: w,
                               height: Swift.max(1, geo.size.height * (maxV > 0 ? v / maxV : 0)))
                }
            }
            .frame(height: geo.size.height, alignment: .bottom)
        }
        .frame(height: height)
    }
}

// MARK: - Small helpers

struct KeyValueRow: View {
    let key: String
    let value: String
    var tint: Color = LL.ink

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(PilcrowFonts.bodyF(11.5))
                .foregroundStyle(LL.ink3)
            Spacer(minLength: 8)
            Text(value)
                .font(PilcrowFonts.monoF(11))
                .foregroundStyle(tint)
        }
    }
}

struct BigStat: View {
    let value: String
    let caption: String
    var tint: Color = LL.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(PilcrowFonts.headingF(23, .heavy))
                .foregroundStyle(tint)
                .monospacedDigit()
            Eyebrow(text: caption)
        }
    }
}

