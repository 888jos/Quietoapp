import SwiftUI

/// The card that comes with a Louane answer when she launches something:
/// a breathing exercise, a guided meditation (with or without a sound under
/// it) or an ambient sound. The whole card is the play button: one action.
struct LouaneLaunchCard: View {
    let session: QuietoSession?
    let ambience: QuietoAmbience?
    let reason: String
    let play: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        Button(action: play) {
            Group {
                if let session, let pattern = session.breathingPattern, session.readerMode == .breathing {
                    BreathingLaunchContent(session: session, pattern: pattern, reason: reason, animated: !reduceMotion)
                } else if let session {
                    MeditationLaunchContent(session: session, ambience: ambience, reason: reason)
                } else if let ambience {
                    AmbienceLaunchContent(ambience: ambience, reason: reason, animated: !reduceMotion)
                }
            }
            .frame(maxWidth: 340, alignment: .leading)
            .quietoSurface(cornerRadius: QuietoRadius.card)
            .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
        }
        .buttonStyle(QuietoPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityHint(reason)
        .accessibilityAddTraits(.isButton)
        // Lined up with the text of Louane's bubble, under her mark.
        .padding(.leading, 30)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion { appeared = true } else { withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.15)) { appeared = true } }
        }
    }

    private var accessibilityTitle: String {
        let names = [session?.title.quietoLocalized, ambience?.title.quietoLocalized].compactMap { $0 }.joined(separator: " + ")
        return QuietoLocalization.format("Lancer %@", names)
    }
}

// MARK: - Shared pieces

/// "Why this one", in Louane's voice, signed with her mark.
private struct LaunchReason: View {
    let text: String
    var body: some View {
        if !text.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                LouaneMark(size: 13, color: QuietoColor.textSecondary)
                Text(verbatim: text)
                    .font(QuietoFont.sans(.subhead))
                    .foregroundStyle(QuietoColor.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct LaunchOverline: View {
    let kind: String
    let minutes: Int?
    var body: some View {
        let parts = [kind.quietoLocalized] + (minutes.map { [QuietoLocalization.format("%d min", $0)] } ?? [])
        Text(verbatim: parts.joined(separator: " · "))
            .quietoOverline()
            .foregroundStyle(QuietoColor.textSecondary)
    }
}

private struct LaunchPlay: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 16, weight: .bold))
            .quietoPlayCircle(QuietoMetrics.playSmall)
            .quietoGlow(radius: 10)
            .accessibilityHidden(true)
    }
}

// MARK: - Breathing

/// A breathing exercise: an orb that breathes at the real rhythm of the
/// pattern, and the cycle drawn to scale (inhale, hold, exhale).
private struct BreathingLaunchContent: View {
    let session: QuietoSession
    let pattern: QuietoBreathingPattern
    let reason: String
    let animated: Bool

    var body: some View {
        let tint = session.goal.tint
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                BreathingOrb(pattern: pattern, tint: tint, animated: animated)
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 5) {
                    LaunchOverline(kind: "Respiration", minutes: session.durationMinutes)
                    Text(session.title.quietoLocalized)
                        .font(QuietoFont.heading(.card, weight: .semibold))
                        .foregroundStyle(QuietoColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if pattern != .counting, !Self.titleIsRhythm(session.title, pattern.rhythm) {
                        Text(verbatim: pattern.rhythm)
                            .font(QuietoFont.sans(.caption, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(tint.top)
                    }
                }
                Spacer(minLength: 0)
                LaunchPlay()
            }
            if !pattern.phases().isEmpty {
                BreathingCycleStrip(phases: pattern.phases(), tint: tint)
            }
            LaunchReason(text: reason)
        }
        .padding(14)
        .background(alignment: .topLeading) {
            // A faint halo of the goal colour behind the orb.
            RadialGradient(colors: [tint.top.opacity(0.22), .clear], center: .init(x: 0.18, y: 0.3), startRadius: 4, endRadius: 170)
        }
    }
}

extension BreathingLaunchContent {
    /// "4-7-8" is both the title and the rhythm: show it once.
    static func titleIsRhythm(_ title: String, _ rhythm: String) -> Bool {
        let digits = { (text: String) in text.filter(\.isNumber) }
        return !digits(title).isEmpty && digits(title) == digits(rhythm)
    }
}

/// Grows on the inhale, rests on the hold, shrinks on the exhale.
private struct BreathingOrb: View {
    let pattern: QuietoBreathingPattern
    let tint: (top: Color, bottom: Color)
    let animated: Bool

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                orb(level: Self.level(pattern: pattern, at: context.date.timeIntervalSinceReferenceDate))
            }
        } else {
            orb(level: 0.6)
        }
    }

    private func orb(level: Double) -> some View {
        let scale = 0.55 + 0.45 * level
        return ZStack {
            Circle().fill(tint.top.opacity(0.12)).scaleEffect(scale * 1.18).blur(radius: 6)
            Circle()
                .fill(RadialGradient(colors: [tint.top.opacity(0.95), tint.bottom.opacity(0.75)], center: .init(x: 0.38, y: 0.32), startRadius: 2, endRadius: 46))
                .overlay(Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1))
                .scaleEffect(scale)
            Circle().stroke(QuietoColor.textPrimary.opacity(0.10), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    /// Lung level (0…1) at `time`, eased within each phase. `counting` has no
    /// imposed rhythm: a slow, regular swell.
    static func level(pattern: QuietoBreathingPattern, at time: TimeInterval) -> Double {
        let phases = pattern.phases()
        let cycle = phases.reduce(0) { $0 + $1.seconds }
        guard cycle > 0 else { return 0.5 + 0.5 * sin(time * 2 * .pi / 10) }
        var t = time.truncatingRemainder(dividingBy: cycle)
        var from = phases.last?.level ?? 0
        for phase in phases {
            if t < phase.seconds {
                let p = t / phase.seconds
                let eased = 0.5 - 0.5 * cos(p * .pi)
                return from + (phase.level - from) * eased
            }
            t -= phase.seconds
            from = phase.level
        }
        return from
    }
}

/// One cycle to scale: each phase is a segment as long as its seconds.
private struct BreathingCycleStrip: View {
    let phases: [QuietoBreathPhase]
    let tint: (top: Color, bottom: Color)

    var body: some View {
        let merged = Self.merge(phases)
        let total = merged.reduce(0) { $0 + $1.seconds }
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(Array(merged.enumerated()), id: \.offset) { _, phase in
                        Capsule()
                            .fill(color(for: phase.kind))
                            .frame(width: max(6, (proxy.size.width - CGFloat(merged.count - 1) * 3) * phase.seconds / total))
                    }
                }
            }
            .frame(height: 6)
            HStack(spacing: 12) {
                ForEach(Array(merged.enumerated()), id: \.offset) { _, phase in
                    HStack(spacing: 4) {
                        Circle().fill(color(for: phase.kind)).frame(width: 6, height: 6)
                        Text(verbatim: "\(phase.label.quietoLocalized) \(Self.seconds(phase.seconds))")
                            .font(QuietoFont.sans(.caption))
                            .monospacedDigit()
                            .foregroundStyle(QuietoColor.textSecondary)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .accessibilityHidden(true)
    }

    private func color(for kind: QuietoBreathPhase.Kind) -> Color {
        switch kind {
        case .inhale: tint.top
        case .hold: QuietoColor.textPrimary.opacity(0.22)
        case .exhale: tint.bottom.opacity(0.7)
        }
    }

    /// Consecutive phases of the same kind (the steps of the staircase, the
    /// double inhale of the sigh) read as one segment.
    static func merge(_ phases: [QuietoBreathPhase]) -> [(kind: QuietoBreathPhase.Kind, seconds: Double, label: String)] {
        var result: [(kind: QuietoBreathPhase.Kind, seconds: Double, label: String)] = []
        for phase in phases {
            if let last = result.last, last.kind == phase.kind {
                result[result.count - 1].seconds += phase.seconds
            } else {
                result.append((phase.kind, phase.seconds, phase.label))
            }
        }
        return result
    }

    static func seconds(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let number = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded)
        return QuietoLocalization.format("%@ s", number)
    }
}

// MARK: - Meditation

/// A guided meditation: its artwork, tinted with the colours of its goal, and
/// the sound that will keep playing under it when Louane added one.
private struct MeditationLaunchContent: View {
    let session: QuietoSession
    let ambience: QuietoAmbience?
    let reason: String

    var body: some View {
        let tint = session.goal.tint
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                QuietoAssetImage(session.imageName, contentMode: .fill)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                LinearGradient(
                    colors: [.clear, tint.bottom.opacity(0.25), QuietoColor.backgroundDeep.opacity(0.92)],
                    startPoint: .top, endPoint: .bottom
                )
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        LaunchOverline(kind: session.practiceType.rawValue, minutes: session.durationMinutes)
                        Text(session.title.quietoLocalized)
                            .font(QuietoFont.heading(.section, weight: .semibold))
                            .foregroundStyle(QuietoColor.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    LaunchPlay()
                }
                .padding(14)
            }
            .frame(height: 150)

            if !reason.isEmpty || ambience != nil {
                VStack(alignment: .leading, spacing: 10) {
                    LaunchReason(text: reason)
                    if let ambience { AmbienceUnderneath(ambience: ambience) }
                }
                .padding(14)
            }
        }
    }
}

/// "With Rain on the window underneath": the sound added to a meditation.
private struct AmbienceUnderneath: View {
    let ambience: QuietoAmbience
    var body: some View {
        HStack(spacing: 10) {
            QuietoAssetImage(ambience.assetName, contentMode: .fill)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Avec un son en fond").font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                Text(ambience.title.quietoLocalized).font(QuietoFont.sans(.subhead, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary)
            }
            Spacer(minLength: 0)
            Image(systemName: "waveform").font(.system(size: 14, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary)
        }
        .padding(8)
        .background(QuietoColor.surfaceRaised, in: RoundedRectangle(cornerRadius: QuietoRadius.small, style: .continuous))
    }
}

// MARK: - Ambient sound

/// An ambient sound: its artwork as a window, with a slow living equalizer.
private struct AmbienceLaunchContent: View {
    let ambience: QuietoAmbience
    let reason: String
    let animated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                QuietoAssetImage(ambience.assetName, contentMode: .fill)
                    .frame(height: 118)
                    .frame(maxWidth: .infinity)
                    .clipped()
                LinearGradient(colors: [.clear, QuietoColor.backgroundDeep.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Son d’ambiance").quietoOverline().foregroundStyle(QuietoColor.textSecondary)
                        Text(ambience.title.quietoLocalized)
                            .font(QuietoFont.heading(.section, weight: .semibold))
                            .foregroundStyle(QuietoColor.textPrimary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    SoundBars(animated: animated).frame(width: 34, height: 26)
                    LaunchPlay()
                }
                .padding(14)
            }
            .frame(height: 118)
            VStack(alignment: .leading, spacing: 6) {
                Text(ambience.subtitle.quietoLocalized).font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                LaunchReason(text: reason)
            }
            .padding(14)
        }
    }
}

/// Five soft bars rising and falling out of step, like a sound breathing.
private struct SoundBars: View {
    let animated: Bool
    private let speeds: [Double] = [0.9, 1.3, 0.7, 1.1, 0.8]

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1 / 24)) { context in
                bars(time: context.date.timeIntervalSinceReferenceDate)
            }
        } else {
            bars(time: 0)
        }
    }

    private func bars(time: TimeInterval) -> some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(speeds.indices, id: \.self) { index in
                let wave = 0.5 + 0.5 * sin(time * speeds[index] * 2 + Double(index) * 1.7)
                Capsule()
                    .fill(QuietoColor.textPrimary.opacity(0.75))
                    .frame(width: 4, height: 6 + 20 * wave)
            }
        }
        .frame(maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}
