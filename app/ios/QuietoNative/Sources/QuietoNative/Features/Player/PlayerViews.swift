import SwiftUI
import UIKit

struct MiniPlayerView: View {
    @ObservedObject var player: QuietoAudioPlayer
    let open: () -> Void

    private var progress: Double { player.duration > 0 ? min(1, player.position / player.duration) : 0 }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    QuietoAssetImage(player.currentSession?.imageName ?? "RecentSession", contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.small, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text((player.currentSession?.title ?? "").quietoLocalized)
                            .font(QuietoFont.sans(.callout, weight: .semibold))
                            .foregroundStyle(QuietoColor.textPrimary)
                            .lineLimit(1)
                        Capsule().fill(QuietoColor.textPrimary.opacity(0.14))
                            .frame(height: 3)
                            .overlay(alignment: .leading) {
                                GeometryReader { proxy in
                                    Capsule().fill(QuietoColor.mint).frame(width: proxy.size.width * progress)
                                }
                            }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(QuietoLocalization.format("Ouvrir le lecteur : %@", (player.currentSession?.title ?? "").quietoLocalized))

            Button { player.toggle() } label: {
                Group {
                    if player.isLoading {
                        ProgressView().tint(QuietoColor.background)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(QuietoColor.background)
                    }
                }
                .frame(width: QuietoMetrics.playSmall, height: QuietoMetrics.playSmall)
                .background(QuietoColor.mintFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel((player.isPlaying ? "Mettre en pause" : "Reprendre").quietoLocalized)

            Button { player.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(QuietoColor.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(QuietoColor.textPrimary.opacity(0.08), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -8)
            .accessibilityLabel("Fermer le lecteur".quietoLocalized)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 9)
        .background(
            LinearGradient(colors: [QuietoColor.miniPlayerTop, QuietoColor.surfaceSolid], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous).stroke(QuietoColor.textPrimary.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .frame(maxWidth: 360)
        .padding(.horizontal, 28)
    }
}

struct NowPlayingView: View {
    @ObservedObject var player: QuietoAudioPlayer
    private var session: QuietoSession? { player.currentSession }
    var body: some View {
        ZStack {
            QuietoBackground()
            if let session {
                // The artwork bleeds into the sky so each session has its own light.
                Color.clear
                    .overlay { QuietoAssetImage(session.imageName, contentMode: .fill) }
                    .clipped()
                    .blur(radius: 60)
                    .opacity(0.85)
                    .mask(LinearGradient(colors: [.white, .white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                ScrollView {
                    VStack(spacing: 22) {
                        QuietoAssetImage(session.imageName, contentMode: .fill).frame(maxWidth: 330).aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: QuietoRadius.hero, style: .continuous)).overlay { RoundedRectangle(cornerRadius: QuietoRadius.hero, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1) }.shadow(color: .black.opacity(0.4), radius: 30, y: 16)
                        VStack(spacing: 7) { Text(session.title.quietoLocalized).font(QuietoFont.heading(.title, weight: .semibold)).multilineTextAlignment(.center); Text(QuietoLocalization.format("Quieto · %@", session.practiceType.rawValue.quietoLocalized)).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary) }
                        if session.readerMode == .breathing { BreathingVisual(session: session, player: player) }
                        Slider(value: Binding(get: { player.position }, set: { player.seek(to: $0) }), in: 0...max(player.duration, 1)).tint(QuietoColor.mint)
                        HStack { Text(verbatim: time(player.position)); Spacer(); Text(verbatim: "−\(time(max(0, player.duration - player.position)))") }.font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
                        HStack(spacing: 38) {
                            Button { player.skip(by: -15) } label: { Image(systemName: "gobackward.15") }
                            Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 28, weight: .semibold)).foregroundStyle(QuietoColor.background).frame(width: QuietoMetrics.playLarge, height: QuietoMetrics.playLarge).background(QuietoColor.mintFill, in: Circle()).quietoGlow(radius: 20) }
                            Button { player.skip(by: 15) } label: { Image(systemName: "goforward.15") }
                        }.font(.system(size: 25)).foregroundStyle(QuietoColor.textPrimary)
                        HStack(spacing: 12) {
                            Image(systemName: "timer")
                            Menu { ForEach([5, 10, 20, 30, 45, 60], id: \.self) { min in Button(QuietoLocalization.format("%d min", min)) { player.setSleepTimer(minutes: min) } }; Button("Désactiver") { player.setSleepTimer(minutes: nil) } } label: { Text(player.timerRemaining.map { QuietoLocalization.format("Arrêt dans %d min", Int(ceil($0 / 60))) } ?? "Minuterie".quietoLocalized) }
                        }.font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
                        if let ambience = player.selectedAmbience { Text(QuietoLocalization.format("Ambiance · %@", ambience.title.quietoLocalized)).font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary) }
                        if session.readerMode == .guidedVoice {
                            Text(session.localizedTranscript).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary).lineSpacing(5).frame(maxWidth: 560, alignment: .leading)
                        }
                    }.padding(.horizontal, QuietoSpacing.lg).padding(.top, 28).padding(.bottom, 38)
                }
            } else { EmptyState(title: "Aucune séance", message: "Choisis une séance pour commencer.") }
        }
        // Badges earned by the session that just ended.
        .badgeCelebrationOverlay(topPadding: 18)
        .preferredColorScheme(.dark)
    }
    private func time(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}

/// Roller-coaster breathing guide: the track scrolls from right to left under a
/// fixed marker. Climbing = inhale, flat = hold, going down = exhale.
struct BreathingVisual: View {
    let session: QuietoSession
    @ObservedObject var player: QuietoAudioPlayer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastPhaseKey = ""
    @State private var count = 0

    private var pattern: QuietoBreathingPattern { session.breathingPattern ?? .coherence }
    /// Seconds of track visible on screen; the marker sits at 30 % of the width.
    private var window: Double { min(26, max(14, pattern.cycleDuration * 2.2)) }
    private let markerRatio = 0.3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !player.isPlaying)) { context in
            let elapsed = player.breathingElapsed(at: context.date)
            let moment = pattern.moment(at: elapsed, total: player.duration)
            VStack(spacing: 14) {
                header(moment)
                if pattern == .counting { counter } else { track(elapsed: elapsed, level: moment.level) }
                footer(moment)
            }
            .opacity(pattern == .sleepDescent ? 1 - 0.45 * min(1, elapsed / max(1, player.duration)) : 1)
            .onChange(of: phaseKey(moment)) { _, key in
                guard player.isPlaying, !lastPhaseKey.isEmpty, key != lastPhaseKey else { lastPhaseKey = key; return }
                lastPhaseKey = key
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title(moment).quietoLocalized)
        }
    }

    private func phaseKey(_ moment: QuietoBreathingPattern.Moment) -> String { "\(moment.cycle)-\(moment.phaseIndex)" }

    private func title(_ moment: QuietoBreathingPattern.Moment) -> String {
        if pattern == .counting { return "Compte tes expirations" }
        if moment.cycle == 0 { return "Prépare-toi" }
        guard let phase = moment.phase else { return "Respire librement" }
        return phase.label
    }

    private func header(_ moment: QuietoBreathingPattern.Moment) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title(moment).quietoLocalized)
                    .font(QuietoFont.heading(.title, weight: .semibold))
                if pattern != .counting, moment.phase != nil || moment.cycle == 0 {
                    Text(verbatim: "\(Int(ceil(max(0, moment.remaining - 0.05))))")
                        .font(QuietoFont.sans(.figure, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(QuietoColor.mint)
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            Text((moment.phase?.sideLabel ?? (moment.cycle == 0 && pattern == .alternate ? "Commence par la narine gauche" : " ")).quietoLocalized)
                .font(QuietoFont.sans(.callout, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
        }
    }

    private func track(elapsed: Double, level: Double) -> some View {
        Canvas { context, size in
            let inset: CGFloat = 14
            let height = size.height - inset * 2
            let markerX = size.width * markerRatio
            func y(_ level: Double) -> CGFloat { inset + (1 - CGFloat(level)) * height }
            var past = Path(), future = Path()
            let steps = Int(size.width / 3)
            for step in 0...steps {
                let x = size.width * CGFloat(step) / CGFloat(steps)
                let time = elapsed + Double((x - markerX) / size.width) * window
                let point = CGPoint(x: x, y: y(time < 0 ? 0 : pattern.moment(at: time, total: player.duration).level))
                if x <= markerX {
                    if past.isEmpty { past.move(to: point) } else { past.addLine(to: point) }
                }
                if x >= markerX - size.width / CGFloat(steps) {
                    if future.isEmpty { future.move(to: point) } else { future.addLine(to: point) }
                }
            }
            let style = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            context.stroke(future, with: .color(QuietoColor.mint.opacity(0.35)), style: style)
            context.stroke(past, with: .color(QuietoColor.mint), style: style)
            let marker = CGRect(x: markerX - 11, y: y(level) - 11, width: 22, height: 22)
            if !reduceMotion {
                context.fill(Path(ellipseIn: marker.insetBy(dx: -8, dy: -8)), with: .color(QuietoColor.mint.opacity(0.18)))
            }
            context.fill(Path(ellipseIn: marker), with: .color(QuietoColor.mint))
        }
        .frame(height: 130)
    }

    private var counter: some View {
        Button {
            count = count % 10 + 1
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
        } label: {
            VStack(spacing: 6) {
                Text(verbatim: count == 0 ? "–" : "\(count)")
                    .font(QuietoFont.heading(.numeral, weight: .semibold)).monospacedDigit()
                    .contentTransition(.numericText())
                Text("Touche à chaque expiration".quietoLocalized)
                    .font(QuietoFont.sans(.subhead)).foregroundStyle(QuietoColor.textSecondary)
            }
            .frame(maxWidth: .infinity).frame(height: 130)
            .quietoSurface(cornerRadius: QuietoRadius.card)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Compter une expiration")
    }

    private func footer(_ moment: QuietoBreathingPattern.Moment) -> some View {
        let rhythm = pattern.rhythm.quietoLocalized
        return Text(moment.cycle > 0 ? QuietoLocalization.format("Cycle %d · %@", moment.cycle, rhythm) : rhythm)
            .font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary)
    }
}

// MARK: - Full-screen breathing exercise

/// Presents the breathing guide above whatever is on screen (a session sheet
/// included), which a SwiftUI cover attached to the root could not do.
@MainActor
enum BreathingExercisePresenter {
    static func present(player: QuietoAudioPlayer) {
        guard let session = player.currentSession, session.readerMode == .breathing,
              let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?.rootViewController else { return }
        var top = root
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        guard !(top is BreathingHostingController) else { return }
        let host = BreathingHostingController(session: session, player: player)
        top.present(host, animated: true)
    }
}

final class BreathingHostingController: UIHostingController<BreathingExerciseView> {
    private let session: QuietoSession
    private let player: QuietoAudioPlayer

    init(session: QuietoSession, player: QuietoAudioPlayer) {
        self.session = session
        self.player = player
        let closer = Closer()
        super.init(rootView: BreathingExerciseView(session: session, player: player, onClose: { closer.close() }))
        closer.controller = self
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
        overrideUserInterfaceStyle = .dark
    }

    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Nobody should have to touch the screen to keep it lit mid-exercise.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// The exercise ends once the guide has faded out, so the closing frames
    /// still show where the person was (the ambience keeps playing).
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if player.currentSession?.id == session.id { player.endSession() }
    }

    private final class Closer {
        weak var controller: UIViewController?
        func close() { controller?.dismiss(animated: true) }
    }
}

/// The breathing exercise, full screen: the phase in large type, a wide
/// roller-coaster track scrolling under a glowing marker (climbing = inhale,
/// flat = hold, going down = exhale) and a light that swells with each breath.
struct BreathingExerciseView: View {
    let session: QuietoSession
    @ObservedObject var player: QuietoAudioPlayer
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastPhaseKey = ""
    @State private var finished = false
    @State private var count = 0

    private var pattern: QuietoBreathingPattern { session.breathingPattern ?? .coherence }
    /// Seconds of track on screen; the marker sits at 32 % of the width.
    private var window: Double { min(24, max(13, pattern.cycleDuration * 2)) }
    private let markerRatio = 0.32

    var body: some View {
        ZStack {
            QuietoBackground()
            if finished {
                completion.transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                exercise.transition(.opacity)
            }
        }
        .foregroundStyle(QuietoColor.textPrimary)
        .animation(.easeInOut(duration: 0.5), value: finished)
        .onChange(of: player.breathingCompletions) { _, _ in
            finished = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: Exercise

    private var exercise: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !player.isPlaying)) { context in
            let elapsed = player.breathingElapsed(at: context.date)
            let moment = pattern.moment(at: elapsed, total: player.duration)
            ZStack {
                breathingLight(level: moment.level)
                VStack(spacing: 0) {
                    topBar(elapsed: elapsed)
                    Spacer(minLength: 12)
                    phaseHeader(moment)
                    Spacer(minLength: 20)
                    if pattern == .counting { counter } else { track(elapsed: elapsed, level: moment.level).frame(height: 260) }
                    Spacer(minLength: 20)
                    bottomBar(moment: moment, elapsed: elapsed)
                }
                .padding(.horizontal, QuietoSpacing.md)
                .padding(.bottom, QuietoSpacing.md)
                // The sleep descent fades out little by little.
                .opacity(pattern == .sleepDescent ? 1 - 0.4 * min(1, elapsed / max(1, player.duration)) : 1)
            }
            .onChange(of: phaseKey(moment)) { _, key in
                guard player.isPlaying, !lastPhaseKey.isEmpty, key != lastPhaseKey else { lastPhaseKey = key; return }
                lastPhaseKey = key
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.75)
            }
        }
    }

    /// A soft mint light that grows on the inhale and fades on the exhale.
    private func breathingLight(level: Double) -> some View {
        RadialGradient(
            colors: [QuietoColor.mint.opacity(0.10 + 0.16 * level), QuietoColor.aurora.opacity(0.06 * level), .clear],
            center: .center, startRadius: 10, endRadius: reduceMotion ? 320 : 220 + 180 * level
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func topBar(elapsed: Double) -> some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(QuietoColor.surface, in: Circle())
                    .overlay(Circle().strokeBorder(QuietoColor.divider, lineWidth: 1))
                    .frame(width: QuietoMetrics.minimumTapTarget, height: QuietoMetrics.minimumTapTarget)
            }
            .buttonStyle(QuietoPressStyle())
            .accessibilityLabel("Arrêter")
            Spacer()
            Text(session.title.quietoLocalized)
                .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.textSecondary)
                .lineLimit(1)
            Spacer()
            Text(verbatim: clock(max(0, player.duration - elapsed)))
                .font(QuietoFont.sans(.callout, weight: .semibold)).monospacedDigit()
                .foregroundStyle(QuietoColor.textSecondary)
                .frame(width: QuietoMetrics.minimumTapTarget + 12, alignment: .trailing)
        }
        .padding(.top, 8)
    }

    private func phaseHeader(_ moment: QuietoBreathingPattern.Moment) -> some View {
        VStack(spacing: 10) {
            Text(title(moment).quietoLocalized)
                .font(QuietoFont.heading(.hero, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.7)
                .id(title(moment))
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity))
            if pattern != .counting, moment.phase != nil || moment.cycle == 0 {
                Text(verbatim: "\(Int(ceil(max(0, moment.remaining - 0.05))))")
                    .font(QuietoFont.sans(.figure, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(QuietoColor.mint)
                    .contentTransition(.numericText(countsDown: true))
            }
            Text((moment.phase?.sideLabel ?? (moment.cycle == 0 && pattern == .alternate ? "Commence par la narine gauche" : " ")).quietoLocalized)
                .font(QuietoFont.sans(.callout, weight: .medium)).foregroundStyle(QuietoColor.textSecondary)
        }
        .animation(.easeInOut(duration: 0.45), value: title(moment))
        .animation(.easeOut(duration: 0.25), value: Int(ceil(max(0, moment.remaining - 0.05))))
        .accessibilityElement(children: .combine)
    }

    private func track(elapsed: Double, level: Double) -> some View {
        let total = player.duration
        let pattern = pattern, window = window, markerRatio = markerRatio, reduceMotion = reduceMotion
        return Canvas { context, size in
            let inset: CGFloat = 26
            let height = size.height - inset * 2
            let markerX = size.width * markerRatio
            func y(_ level: Double) -> CGFloat { inset + (1 - CGFloat(level)) * height }
            func point(at x: CGFloat) -> CGPoint {
                let time = elapsed + Double((x - markerX) / size.width) * window
                return CGPoint(x: x, y: y(time < 0 ? 0 : pattern.moment(at: time, total: total).level))
            }

            // Faint rails at the top and bottom of the breath.
            for railLevel in [0.0, 1.0] {
                var rail = Path()
                rail.move(to: CGPoint(x: 0, y: y(railLevel)))
                rail.addLine(to: CGPoint(x: size.width, y: y(railLevel)))
                context.stroke(rail, with: .color(.white.opacity(0.06)), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
            }

            var past = Path(), future = Path()
            let steps = Int(size.width / 2)
            for step in 0...steps {
                let x = size.width * CGFloat(step) / CGFloat(steps)
                let p = point(at: x)
                if x <= markerX { if past.isEmpty { past.move(to: p) } else { past.addLine(to: p) } }
                if x >= markerX - size.width / CGFloat(steps) { if future.isEmpty { future.move(to: p) } else { future.addLine(to: p) } }
            }
            past.addLine(to: CGPoint(x: markerX, y: y(level)))

            // The road ahead: a faint line over a soft wash of light.
            var area = future
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: markerX, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(Gradient(colors: [QuietoColor.mint.opacity(0.10), .clear]), startPoint: CGPoint(x: 0, y: inset), endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(future, with: .color(QuietoColor.mint.opacity(0.32)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))

            // The road travelled: bright near the marker, fading behind it.
            let fade = Gradient(colors: [QuietoColor.mint.opacity(0), QuietoColor.mint])
            var glow = context
            glow.opacity = 0.22
            glow.stroke(past, with: .linearGradient(fade, startPoint: .zero, endPoint: CGPoint(x: markerX, y: 0)), style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
            context.stroke(past, with: .linearGradient(Gradient(colors: [QuietoColor.mintLight.opacity(0), QuietoColor.mintLight]), startPoint: .zero, endPoint: CGPoint(x: markerX, y: 0)), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

            // The marker: a glowing orb riding the curve.
            let center = CGPoint(x: markerX, y: y(level))
            let halo = reduceMotion ? 22 : 22 + 14 * level
            context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: halo * 2, height: halo * 2)), with: .radialGradient(Gradient(colors: [QuietoColor.mint.opacity(0.45), .clear]), center: center, startRadius: 4, endRadius: halo))
            context.fill(Path(ellipseIn: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24)), with: .color(QuietoColor.mintLight))
            context.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(.white))
        }
        .accessibilityHidden(true)
    }

    private var counter: some View {
        Button {
            count = count % 10 + 1
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        } label: {
            VStack(spacing: 8) {
                Text(verbatim: count == 0 ? "–" : "\(count)")
                    .font(QuietoFont.heading(.numeral, weight: .semibold)).monospacedDigit()
                    .contentTransition(.numericText())
                Text("Touche à chaque expiration".quietoLocalized)
                    .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            }
            .frame(width: 240, height: 240)
            .background(QuietoColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(QuietoColor.mint.opacity(0.35), lineWidth: 1.5))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
        }
        .buttonStyle(QuietoPressStyle())
        .accessibilityLabel("Compter une expiration")
    }

    private func bottomBar(moment: QuietoBreathingPattern.Moment, elapsed: Double) -> some View {
        VStack(spacing: 22) {
            HStack {
                Text(verbatim: moment.cycle > 0 ? QuietoLocalization.format("Cycle %d", moment.cycle) : " ")
                Spacer()
                Text(pattern.rhythm.quietoLocalized)
            }
            .font(QuietoFont.sans(.subhead, weight: .medium)).foregroundStyle(QuietoColor.textSecondary).monospacedDigit()
            GeometryReader { proxy in
                Capsule().fill(QuietoColor.textPrimary.opacity(0.1))
                    .overlay(alignment: .leading) {
                        Capsule().fill(QuietoColor.mintFill)
                            .frame(width: proxy.size.width * min(1, elapsed / max(1, player.duration)))
                    }
            }
            .frame(height: 4)
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .semibold)).foregroundStyle(QuietoColor.background)
                    .frame(width: QuietoMetrics.playLarge, height: QuietoMetrics.playLarge)
                    .background(QuietoColor.mintFill, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                    .quietoGlow(radius: 20)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(QuietoPressStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: player.isPlaying)
            .accessibilityLabel((player.isPlaying ? "Mettre en pause" : "Reprendre").quietoLocalized)
        }
    }

    // MARK: Completion

    private var completion: some View {
        SessionFeedbackView(
            session: session,
            minutes: max(1, Int((player.duration - QuietoBreathingPattern.leadIn) / 60)),
            onFinish: { feeling in
                if let feeling { player.recordFeedback(session, feeling: feeling.id) }
                onClose()
            },
            onRestart: {
                finished = false
                lastPhaseKey = ""
                count = 0
                player.play(session)
            }
        )
    }

    // MARK: Helpers

    private func phaseKey(_ moment: QuietoBreathingPattern.Moment) -> String { "\(moment.cycle)-\(moment.phaseIndex)" }

    private func title(_ moment: QuietoBreathingPattern.Moment) -> String {
        if pattern == .counting { return "Compte tes expirations" }
        if moment.cycle == 0 { return "Prépare-toi" }
        guard let phase = moment.phase else { return "Respire librement" }
        return phase.label
    }

    private func clock(_ seconds: Double) -> String {
        let total = Int(ceil(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}


// MARK: - Session feedback

/// How the person feels once a session or an exercise is over.
enum SessionFeeling: String, CaseIterable, Identifiable {
    case calmer, lighter, same, tense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calmer: "Apaisé·e"
        case .lighter: "Plus léger·e"
        case .same: "Pareil"
        case .tense: "Encore tendu·e"
        }
    }

    var symbol: String {
        switch self {
        case .calmer: "leaf"
        case .lighter: "cloud.sun"
        case .same: "equal"
        case .tense: "waveform.path"
        }
    }
}

/// End of a meditation or a breathing exercise: a short celebration, then
/// « Comment te sens-tu maintenant ? » with four answers. Answering is optional.
struct SessionFeedbackView: View {
    let session: QuietoSession
    let minutes: Int
    let onFinish: (SessionFeeling?) -> Void
    var onRestart: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feeling: SessionFeeling?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: QuietoSpacing.lg) {
            Spacer(minLength: QuietoSpacing.lg)
            Image(systemName: "checkmark")
                .font(.system(size: 34, weight: .bold))
                .quietoPlayCircle(92)
                .quietoGlow(radius: 28)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
            VStack(spacing: 8) {
                Text("Bien joué".quietoLocalized).font(QuietoFont.heading(.hero))
                Text(verbatim: "\(session.title.quietoLocalized) · \(QuietoLocalization.format("%d min", minutes))")
                    .font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
            }
            .multilineTextAlignment(.center)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)

            VStack(spacing: QuietoSpacing.md) {
                Text("Comment te sens-tu maintenant ?".quietoLocalized).font(QuietoFont.section).multilineTextAlignment(.center)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(SessionFeeling.allCases) { option in feelingButton(option) }
                }
            }
            .padding(.top, QuietoSpacing.md)
            .opacity(appeared ? 1 : 0)

            Spacer(minLength: QuietoSpacing.lg)
            VStack(spacing: 12) {
                QuietoPrimaryButton(title: "Terminer", systemImage: nil) { onFinish(feeling) }
                if let onRestart {
                    QuietoOutlineButton(title: "Recommencer", systemImage: "arrow.counterclockwise", action: onRestart)
                }
            }
        }
        .padding(.horizontal, QuietoSpacing.md)
        .padding(.bottom, QuietoSpacing.lg)
        .frame(maxWidth: QuietoMetrics.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .foregroundStyle(QuietoColor.textPrimary)
        .sensoryFeedback(.selection, trigger: feeling)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) { appeared = true }
        }
    }

    private func feelingButton(_ option: SessionFeeling) -> some View {
        let selected = feeling == option
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { feeling = selected ? nil : option }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: option.symbol).font(.system(size: 16, weight: .semibold))
                Text(option.title.quietoLocalized).font(QuietoFont.sans(.callout, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? QuietoColor.background : QuietoColor.textPrimary)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: QuietoMetrics.controlHeight)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous).fill(QuietoColor.mintFill)
                } else {
                    Color.clear.quietoSurface(cornerRadius: QuietoRadius.card)
                }
            }
        }
        .buttonStyle(QuietoPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Opens the feedback screen full screen once a guided session has ended,
/// above the player sheet if it is open.
@MainActor
enum SessionFeedbackPresenter {
    static func present(player: QuietoAudioPlayer) {
        guard let session = player.lastCompletedSession,
              let root = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?.rootViewController else { return }
        var top = root
        while let next = top.presentedViewController, !next.isBeingDismissed { top = next }
        guard !(top is SessionFeedbackHostingController) else { return }
        top.present(SessionFeedbackHostingController(session: session, player: player), animated: true)
    }
}

final class SessionFeedbackHostingController: UIHostingController<AnyView> {
    init(session: QuietoSession, player: QuietoAudioPlayer) {
        let closer = Closer()
        let feedback = SessionFeedbackView(session: session, minutes: session.durationMinutes) { feeling in
            if let feeling { player.recordFeedback(session, feeling: feeling.id) }
            closer.close {
                // The session is over: the mini player and the open player go away.
                if player.currentSession?.id == session.id { player.endSession() }
            }
        }
        super.init(rootView: AnyView(ZStack { QuietoBackground(); feedback }))
        closer.controller = self
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
        overrideUserInterfaceStyle = .dark
    }

    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private final class Closer {
        weak var controller: UIViewController?
        func close(then completion: @escaping () -> Void) { controller?.dismiss(animated: true, completion: completion) ?? completion() }
    }
}
