import SwiftUI

/// Collects the on-screen bounds of every control tagged with
/// `.coachmarkTarget(_:)`, keyed by id, so the overlay can spotlight any of them.
struct CoachmarkAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks this view as a tour target the welcome tour can point at by `id`.
    func coachmarkTarget(_ id: String) -> some View {
        anchorPreference(key: CoachmarkAnchorKey.self, value: .bounds) { [id: $0] }
    }
}

/// The dimming + spotlight + explanation card shown over the whole window during
/// the welcome tour. Lives in `MainWindowView`'s overlay, which resolves the
/// target's anchor into a rect in this view's coordinate space.
struct CoachmarkOverlay: View {
    let step: OnboardingStep
    /// The spotlighted control's frame, already resolved; nil for centered cards.
    let targetRect: CGRect?
    let stepIndex: Int
    let stepCount: Int
    let isLastStep: Bool
    var onNext: () -> Void
    var onBack: () -> Void
    var onSkip: () -> Void

    @State private var cardSize: CGSize = .zero

    private let spotPadding: CGFloat = 8
    private let spotCorner: CGFloat = 10
    private let margin: CGFloat = 18
    private let cardWidth: CGFloat = 290

    private var highlightRect: CGRect? {
        targetRect?.insetBy(dx: -spotPadding, dy: -spotPadding)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                dimmedBackground
                if let rect = highlightRect {
                    RoundedRectangle(cornerRadius: spotCorner)
                        .stroke(Color.accentColor, lineWidth: 2.5)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
                card
                    .frame(width: min(cardWidth, geo.size.width - 2 * margin))
                    .background(cardSizeReader)
                    .position(cardPosition(in: geo.size))
            }
            // No `.ignoresSafeArea()` here: the spotlight is positioned from
            // anchors resolved in this same GeometryReader's coordinate space, so
            // the overlay must keep that exact origin or the highlight drifts off
            // its target (e.g. in a windowed, non-fullscreen window).
        }
        .transition(.opacity)
    }

    /// A black scrim with a transparent hole punched over the target so it stays
    /// bright. Captures clicks so the rest of the UI can't be tapped mid-tour.
    private var dimmedBackground: some View {
        ZStack {
            Color.black.opacity(0.55)
            if let rect = highlightRect {
                RoundedRectangle(cornerRadius: spotCorner)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .contentShape(Rectangle())
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: step.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(step.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Text(step.message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            // Progress and controls live on separate rows so the buttons always
            // have room for their labels (no wrapping/truncation) even on a
            // narrow card.
            VStack(spacing: 12) {
                stepDots
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    if !isLastStep {
                        Button("Skip", action: onSkip)
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                    }

                    Spacer(minLength: 0)

                    if stepIndex > 0 {
                        Button("Back", action: onBack)
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .lineLimit(1)
                            .fixedSize()
                    }

                    Button(action: onNext) {
                        Text(isLastStep ? "Done" : "Next")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.3), radius: 18, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }

    private var stepDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<stepCount, id: \.self) { index in
                Circle()
                    .fill(index == stepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var cardSizeReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { cardSize = proxy.size }
                .onChange(of: proxy.size) { _, newValue in cardSize = newValue }
        }
    }

    /// Places the card just below the spotlight when there's room, otherwise just
    /// above it, clamped to stay fully on screen. Centered when there's no target.
    private func cardPosition(in size: CGSize) -> CGPoint {
        let halfH = cardSize.height / 2
        let halfW = min(cardWidth, size.width - 2 * margin) / 2

        guard let rect = highlightRect, cardSize != .zero else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }

        let x = min(max(rect.midX, margin + halfW), size.width - margin - halfW)

        let below = rect.maxY + margin + halfH
        let above = rect.minY - margin - halfH
        let y: CGFloat
        if below + halfH <= size.height - margin {
            y = below
        } else if above - halfH >= margin {
            y = above
        } else {
            y = size.height / 2
        }
        return CGPoint(x: x, y: y)
    }
}
