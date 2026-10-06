import Charts
import SwiftUI

enum OnboardingLinks {
    static let terms = URL(string: "https://cofonde.com/quieto-cgu")!
    static let privacy = URL(string: "https://cofonde.com/quieto-confidentialite")!
    static let crisisLine = URL(string: "tel:3114")!
    static let emergency = URL(string: "tel:112")!
    /// Must match the free trial configured in App Store Connect.
    static let trialDays = 7
}

struct OnboardingTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.quietoLocalized).font(QuietoFont.serif(31, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle.quietoLocalized).font(QuietoFont.sans(16)).foregroundStyle(QuietoColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.quietoLocalized).font(QuietoFont.sans(17, weight: .semibold)).foregroundStyle(QuietoColor.background)
                .frame(maxWidth: .infinity).frame(minHeight: 54)
                .background(QuietoColor.mint.opacity(enabled ? 1 : 0.35), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct OnboardingSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.quietoLocalized).font(QuietoFont.sans(15, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
                .frame(maxWidth: .infinity).frame(minHeight: QuietoMetrics.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingOptionRow: View {
    let option: OnboardingOption
    let selected: Bool
    let multiple: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let symbol = option.symbol {
                    Image(systemName: symbol).font(.system(size: 18)).frame(width: 26).foregroundStyle(selected ? QuietoColor.background : QuietoColor.mint)
                }
                Text(option.label.quietoLocalized).font(QuietoFont.sans(16, weight: .medium)).multilineTextAlignment(.leading)
                Spacer()
                if multiple {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 20))
                }
            }
            .foregroundStyle(selected ? QuietoColor.background : QuietoColor.textPrimary)
            .padding(.horizontal, 18).frame(minHeight: 58)
            .background(selected ? QuietoColor.mint : QuietoColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? Color.clear : QuietoColor.divider) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

struct OnboardingProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(QuietoColor.surface)
                Capsule().fill(QuietoColor.mint).frame(width: max(6, proxy.size.width * value))
            }
        }
        .frame(height: 5)
        .animation(.easeInOut(duration: 0.35), value: value)
        .accessibilityElement()
        .accessibilityLabel("Progression")
        .accessibilityValue("\(Int(value * 100)) %")
    }
}

/// 0–10 scale used before and after the first breathing exercise.
struct OnboardingScale: View {
    @Binding var value: Double

    private var caption: String {
        switch Int(value.rounded()) {
        case 0...2: "Plutôt serein·e"
        case 3...5: "Un peu tendu·e"
        case 6...8: "Tendu·e"
        default: "Au bord de la saturation"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("\(Int(value.rounded()))").font(QuietoFont.serif(72, weight: .semibold)).contentTransition(.numericText())
            Text(caption.quietoLocalized).font(QuietoFont.sans(16)).foregroundStyle(QuietoColor.textSecondary)
            Slider(value: $value, in: 0...10, step: 1).tint(QuietoColor.mint)
            HStack { Text("Calme"); Spacer(); Text("Très stressé·e") }.font(QuietoFont.sans(13)).foregroundStyle(QuietoColor.textSecondary)
        }
        .animation(.easeOut(duration: 0.15), value: value)
    }
}

/// Inhale 4 s, exhale 6 s: the long exhale that calms the nervous system.
struct OnboardingBreathingCircle: View {
    let totalSeconds: Int
    let onFinished: () -> Void
    @State private var expanded = false
    @State private var remaining: Int
    @State private var inhaling = true
    @State private var timer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(totalSeconds: Int = 60, onFinished: @escaping () -> Void) {
        self.totalSeconds = totalSeconds
        self.onFinished = onFinished
        _remaining = State(initialValue: totalSeconds)
    }

    var body: some View {
        VStack(spacing: 34) {
            ZStack {
                Circle().fill(QuietoColor.mint.opacity(0.12)).frame(width: 260, height: 260)
                Circle().fill(QuietoColor.mint.opacity(0.35))
                    .frame(width: 260, height: 260)
                    .scaleEffect(reduceMotion ? 0.75 : (expanded ? 1 : 0.45))
                Text((inhaling ? "Inspire" : "Expire").quietoLocalized).font(QuietoFont.serif(30, weight: .semibold))
            }
            Text(String(format: "%d s", remaining)).font(QuietoFont.sans(15)).foregroundStyle(QuietoColor.textSecondary).monospacedDigit()
        }
        .onAppear(perform: start)
        .onDisappear { timer?.invalidate() }
        .accessibilityElement(children: .combine)
    }

    private func start() {
        cycle()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                remaining -= 1
                if remaining <= 0 { timer?.invalidate(); onFinished() }
            }
        }
    }

    private func cycle() {
        guard remaining > 0 else { return }
        inhaling = true
        withAnimation(.easeInOut(duration: 4)) { expanded = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard remaining > 0 else { return }
            inhaling = false
            withAnimation(.easeInOut(duration: 6)) { expanded = false }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { cycle() }
        }
    }
}

/// Press and hold to commit: a small physical gesture that makes it personal.
struct OnboardingHoldButton: View {
    let title: String
    let onCompleted: () -> Void
    @State private var progress: Double = 0
    @State private var done = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(QuietoColor.surface)
            GeometryReader { proxy in
                Capsule().fill(QuietoColor.mint).frame(width: proxy.size.width * progress)
            }
            Text((done ? "C’est noté ✓" : title).quietoLocalized).font(QuietoFont.sans(17, weight: .semibold))
                .foregroundStyle(progress > 0.5 ? QuietoColor.background : QuietoColor.textPrimary)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 58)
        .clipShape(Capsule())
        .onLongPressGesture(minimumDuration: 1.4, maximumDistance: 40) {
            done = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onCompleted()
        } onPressingChanged: { pressing in
            guard !done else { return }
            withAnimation(pressing ? .linear(duration: 1.4) : .easeOut(duration: 0.2)) { progress = pressing ? 1 : 0 }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title.quietoLocalized)
        .accessibilityAction { done = true; onCompleted() }
    }
}

/// Louane-style chat bubbles that appear one after the other.
struct OnboardingBubbles: View {
    let bubbles: [String]
    var onAllShown: (() -> Void)? = nil
    @State private var visible = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(bubbles.prefix(visible).enumerated()), id: \.offset) { _, text in
                HStack(alignment: .top, spacing: 8) {
                    LouaneMark(size: 24)
                    Text(text.quietoLocalized).font(QuietoFont.sans(16)).padding(13)
                        .background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 16))
                    Spacer(minLength: 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task {
            for index in bubbles.indices {
                try? await Task.sleep(nanoseconds: index == 0 ? 300_000_000 : 1_100_000_000)
                withAnimation(.easeOut(duration: 0.3)) { visible = index + 1 }
            }
            onAllShown?()
        }
    }
}

/// Illustrative stress curve. Labelled as such: it is not a promise.
struct OnboardingProjectionChart: View {
    let start: Double

    private var points: [(week: Int, value: Double)] {
        (0...4).map { week in (week, max(1.5, start - Double(week) * max(0.6, (start - 2) / 4))) }
    }

    var body: some View {
        Chart(points, id: \.week) { point in
            AreaMark(x: .value("Semaine", point.week), y: .value("Stress", point.value))
                .foregroundStyle(LinearGradient(colors: [QuietoColor.mint.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Semaine", point.week), y: .value("Stress", point.value))
                .foregroundStyle(QuietoColor.mint)
                .lineStyle(StrokeStyle(lineWidth: 3))
                .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: 0...10)
        .chartXScale(domain: -0.15...4.15)
        .chartXAxis {
            AxisMarks(values: [0, 1, 2, 3, 4]) { value in
                AxisValueLabel { Text(value.as(Int.self).map { $0 == 0 ? "Auj." : "S\($0)" } ?? "").foregroundStyle(QuietoColor.textSecondary) }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 200)
        .accessibilityLabel("Projection illustrative : un stress qui diminue au fil des semaines de pratique")
    }
}

struct OnboardingSessionRow: View {
    let day: Int
    let session: QuietoSession

    var body: some View {
        HStack(spacing: 12) {
            QuietoAssetImage(session.imageName, contentMode: .fill).frame(width: 64, height: 52).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: "Jour %d".quietoLocalized, day)).font(QuietoFont.sans(12, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                Text(session.title.quietoLocalized).font(QuietoFont.serif(19, weight: .semibold)).lineLimit(1)
                Text("\(session.durationMinutes) min · \(session.practiceType.rawValue.quietoLocalized)").font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary)
            }
            Spacer()
            Image(systemName: day == 1 ? "play.circle.fill" : "lock.fill").foregroundStyle(day == 1 ? QuietoColor.mint : QuietoColor.textSecondary)
        }
        .padding(10)
        .background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct OnboardingLegalLinks: View {
    var body: some View {
        HStack(spacing: 16) {
            Link("Conditions", destination: OnboardingLinks.terms)
            Link("Confidentialité", destination: OnboardingLinks.privacy)
        }
        .font(QuietoFont.sans(12)).foregroundStyle(QuietoColor.textSecondary)
    }
}
