import SwiftUI
import UIKit

/// Lengths offered for a background sound. nil = until the person stops it.
enum AmbienceDuration {
    static let presets: [TimeInterval?] = [nil, 30, 60, 5 * 60, 15 * 60, 30 * 60, 60 * 60, 2 * 3600, 8 * 3600]

    static func label(_ seconds: TimeInterval?) -> String {
        guard let seconds else { return "Sans limite".quietoLocalized }
        if seconds < 60 { return QuietoLocalization.format("%d s", Int(seconds)) }
        if seconds < 3600 { return QuietoLocalization.format("%d min", Int(seconds / 60)) }
        let hours = Int(seconds / 3600), minutes = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        return minutes == 0 ? QuietoLocalization.format("%d h", hours) : QuietoLocalization.format("%d h %d", hours, minutes)
    }

    static func countdown(_ seconds: TimeInterval) -> String {
        let total = Int(ceil(seconds))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Full screen for a background sound: play/pause, volume and how long it lasts.
/// The sound keeps playing with the app closed or the screen locked.
struct AmbiencePlayerView: View {
    @ObservedObject var player: QuietoAudioPlayer
    @State private var chosen: TimeInterval?? = .none
    @State private var showingCustom = false
    @State private var custom: TimeInterval = 20 * 60

    var body: some View {
        ZStack {
            QuietoBackground()
            if let ambience = player.selectedAmbience {
                ScrollView {
                    VStack(spacing: 22) {
                        QuietoAssetImage(ambience.assetName, contentMode: .fill)
                            .frame(maxWidth: 300).aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.hero, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 22, y: 10)
                        VStack(spacing: 6) {
                            Text(ambience.title.quietoLocalized).font(QuietoFont.heading(.title, weight: .semibold))
                            Text(ambience.subtitle.quietoLocalized).font(QuietoFont.sans(.callout)).foregroundStyle(QuietoColor.textSecondary)
                        }
                        remaining
                        controls
                        durationPicker
                        volume
                    }
                    .padding(.horizontal, QuietoSpacing.lg).padding(.top, 28).padding(.bottom, 38)
                    .frame(maxWidth: QuietoMetrics.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
            } else {
                EmptyState(title: "Aucun son en cours", message: "Choisis un son d’ambiance pour commencer.")
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingCustom) { customSheet }
        // Highlights « Sans limite » when no timer is set; a running timer shows its own countdown.
        .onAppear { if player.ambienceRemaining == nil { chosen = .some(nil) } }
    }

    private var remaining: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Group {
                if let left = player.ambienceRemaining {
                    Label(QuietoLocalization.format("Arrêt dans %@", AmbienceDuration.countdown(left)), systemImage: "timer")
                } else {
                    Label("Sans limite", systemImage: "infinity")
                }
            }
            .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.mint)
            .monospacedDigit()
        }
    }

    private var controls: some View {
        HStack(spacing: 40) {
            Button { player.stopAmbience(); player.isAmbiencePlayerPresented = false } label: {
                Image(systemName: "stop.fill").font(.system(size: 20)).foregroundStyle(QuietoColor.textPrimary)
                    .frame(width: 52, height: 52).background(QuietoColor.surface, in: Circle())
            }
            .accessibilityLabel("Arrêter le son")
            Button { player.toggleAmbience() } label: {
                Image(systemName: player.isAmbiencePlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(QuietoColor.background)
                    .frame(width: QuietoMetrics.playLarge, height: QuietoMetrics.playLarge).background(QuietoColor.mintFill, in: Circle()).quietoGlow(radius: 18)
            }
            .accessibilityLabel((player.isAmbiencePlaying ? "Mettre en pause" : "Reprendre").quietoLocalized)
            Color.clear.frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Durée").font(QuietoFont.sans(.callout, weight: .semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(AmbienceDuration.presets.enumerated()), id: \.offset) { _, value in
                        chip(AmbienceDuration.label(value), selected: chosen.map { $0 == value } ?? false) {
                            chosen = .some(value)
                            player.setAmbienceDuration(value)
                        }
                    }
                    chip("Personnaliser".quietoLocalized, selected: false) { showingCustom = true }
                }
                .padding(.horizontal, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.quietoLocalized)
                .font(QuietoFont.sans(.callout, weight: .medium))
                .foregroundStyle(selected ? QuietoColor.background : QuietoColor.textPrimary)
                .padding(.horizontal, 14).frame(height: 38)
                .background(selected ? QuietoColor.mint : QuietoColor.surface, in: Capsule())
                .overlay { if !selected { Capsule().stroke(QuietoColor.divider) } }
        }
        .buttonStyle(.plain)
    }

    private var volume: some View {
        HStack {
            Image(systemName: "speaker.fill")
            Slider(value: $player.ambienceVolume, in: 0...1)
            Image(systemName: "speaker.wave.3.fill")
        }
        .foregroundStyle(QuietoColor.textSecondary).tint(QuietoColor.mint)
        .accessibilityLabel("Volume du son")
    }

    private var customSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                CountdownPicker(duration: $custom).frame(height: 216)
                QuietoPrimaryButton(title: QuietoLocalization.format("Arrêter après %@", AmbienceDuration.label(custom)), systemImage: "timer") {
                    chosen = .some(custom)
                    player.setAmbienceDuration(custom)
                    showingCustom = false
                }
            }
            .padding(QuietoSpacing.md)
            .navigationTitle(Text("Durée du son".quietoLocalized))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

/// UIKit's hours/minutes wheel (SwiftUI has no countdown picker).
private struct CountdownPicker: UIViewRepresentable {
    @Binding var duration: TimeInterval

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .countDownTimer
        picker.countDownDuration = duration
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        if abs(picker.countDownDuration - duration) > 1 { picker.countDownDuration = duration }
    }

    func makeCoordinator() -> Coordinator { Coordinator(duration: $duration) }

    final class Coordinator: NSObject {
        let duration: Binding<TimeInterval>
        init(duration: Binding<TimeInterval>) { self.duration = duration }
        @objc func changed(_ picker: UIDatePicker) { duration.wrappedValue = picker.countDownDuration }
    }
}

/// Shown above the tab bar when only a sound is playing.
struct AmbienceMiniPlayerView: View {
    @ObservedObject var player: QuietoAudioPlayer

    var body: some View {
        if let ambience = player.selectedAmbience {
            HStack(spacing: 12) {
                Button { player.isAmbiencePlayerPresented = true } label: {
                    HStack(spacing: 12) {
                        QuietoAssetImage(ambience.assetName, contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.small, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ambience.title.quietoLocalized)
                                .font(QuietoFont.sans(.callout, weight: .semibold)).foregroundStyle(QuietoColor.textPrimary).lineLimit(1)
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                Text(player.ambienceRemaining.map { QuietoLocalization.format("Arrêt dans %@", AmbienceDuration.countdown($0)) } ?? "Son d’ambiance".quietoLocalized)
                                    .font(QuietoFont.sans(.caption)).foregroundStyle(QuietoColor.textSecondary).monospacedDigit()
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button { player.toggleAmbience() } label: {
                    Image(systemName: player.isAmbiencePlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(QuietoColor.background)
                        .frame(width: QuietoMetrics.playSmall, height: QuietoMetrics.playSmall).background(QuietoColor.mintFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel((player.isAmbiencePlaying ? "Mettre en pause" : "Reprendre").quietoLocalized)
                Button { player.stopAmbience() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(QuietoColor.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(QuietoColor.textPrimary.opacity(0.08), in: Circle())
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, -8)
                .accessibilityLabel("Arrêter le son")
            }
            .padding(.leading, 10).padding(.trailing, 12).padding(.vertical, 9)
            .background(
                LinearGradient(colors: [QuietoColor.miniPlayerTop, QuietoColor.surfaceSolid], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous)
            )
            .overlay { RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous).stroke(QuietoColor.textPrimary.opacity(0.09), lineWidth: 1) }
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            .frame(maxWidth: 360)
            .padding(.horizontal, 28)
        }
    }
}

/// Ambiences as a compact sideways row: the name sits on the artwork. A tap
/// starts the sound right away (or pauses / resumes the one playing); the full
/// ambience player only opens from the mini player.
struct AmbienceRow: View {
    @ObservedObject var player: QuietoAudioPlayer
    /// Adds a first « Aucune » tile that stops the sound (session sheet).
    var showsNoneTile = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if showsNoneTile { noneTile }
                ForEach(QuietoAmbience.all) { ambience in
                    let selected = player.selectedAmbience == ambience
                    Button {
                        if selected { player.toggleAmbience() } else { player.playAmbience(ambience) }
                    } label: {
                        QuietoAssetImage(ambience.assetName, contentMode: .fill)
                            .frame(width: 92, height: 92)
                            .overlay {
                                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                            }
                            .overlay(alignment: .bottomLeading) {
                                Text(ambience.title.quietoLocalized)
                                    .font(QuietoFont.sans(.caption, weight: .semibold)).foregroundStyle(.white)
                                    .lineLimit(2).multilineTextAlignment(.leading)
                                    .padding(.horizontal, 8).padding(.bottom, 7)
                            }
                            .overlay(alignment: .topTrailing) {
                                if selected {
                                    Image(systemName: player.isAmbiencePlaying ? "speaker.wave.2.fill" : "pause.fill")
                                        .font(.system(size: 10, weight: .bold)).foregroundStyle(QuietoColor.background)
                                        .frame(width: 22, height: 22).background(QuietoColor.mintFill, in: Circle())
                                        .padding(6)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous)
                                    .strokeBorder(selected ? QuietoColor.mint : QuietoColor.divider, lineWidth: selected ? 2 : 1)
                            }
                    }
                    .buttonStyle(QuietoPressStyle())
                    .accessibilityLabel(ambience.title.quietoLocalized)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.trailing, QuietoSpacing.md)
        }
        .padding(.trailing, -QuietoSpacing.md)
        .sensoryFeedback(.selection, trigger: player.selectedAmbience)
    }

    private var noneTile: some View {
        let selected = player.selectedAmbience == nil
        return Button { player.stopAmbience() } label: {
            VStack(spacing: 8) {
                Image(systemName: "speaker.slash").font(.system(size: 22, weight: .medium))
                Text("Aucune".quietoLocalized).font(QuietoFont.sans(.caption, weight: .semibold))
            }
            .foregroundStyle(selected ? QuietoColor.mint : QuietoColor.textSecondary)
            .frame(width: 92, height: 92)
            .quietoSurface(cornerRadius: QuietoRadius.card)
            .overlay {
                RoundedRectangle(cornerRadius: QuietoRadius.card, style: .continuous)
                    .strokeBorder(selected ? QuietoColor.mint : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(QuietoPressStyle())
        .accessibilityLabel("Aucune ambiance".quietoLocalized)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
