import SwiftUI

enum QuietoColor {
    static let background = Color(red: 0.063, green: 0.114, blue: 0.188) // #101D30
    /// Bottom of the night sky, a shade deeper than `background`.
    static let backgroundDeep = Color(red: 0.035, green: 0.071, blue: 0.133) // #091222
    /// Top of the night sky: dusk indigo.
    static let backgroundDusk = Color(red: 0.118, green: 0.157, blue: 0.318) // #1E2851
    /// Faint violet glow of the sky; never used for text or controls.
    static let aurora = Color(red: 0.494, green: 0.420, blue: 0.851) // #7E6BD9
    /// Cards are translucent so the sky shows through them. Over `background`
    /// it reads as the former opaque #1B2D43.
    static let surface = Color(red: 0.62, green: 0.76, blue: 1.0).opacity(0.10)
    static let surfaceRaised = Color(red: 0.62, green: 0.76, blue: 1.0).opacity(0.07)
    /// Opaque surface for floating elements over scrolling content (mini players).
    static let surfaceSolid = Color(red: 0.106, green: 0.176, blue: 0.263) // #1B2D43
    static let mint = Color(red: 0.659, green: 0.898, blue: 0.835) // #A8E5D5
    static let mintLight = Color(red: 0.792, green: 0.949, blue: 0.902) // #CAF2E6
    static let mintDeep = Color(red: 0.522, green: 0.820, blue: 0.741) // #85D1BD
    /// Fill of primary actions: a soft vertical sheen on mint.
    static let mintFill = LinearGradient(colors: [mintLight, mint, mintDeep], startPoint: .top, endPoint: .bottom)
    /// Top of the mini player gradient, a lighter shade of `surface`.
    static let miniPlayerTop = Color(red: 0.149, green: 0.235, blue: 0.345) // #263C58
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.66)
    static let divider = Color.white.opacity(0.13)
    /// Destructive actions and errors only.
    static let danger = Color(red: 1.0, green: 0.478, blue: 0.478) // #FF7A7A
    /// Warm accent for favourites and health.
    static let coral = Color(red: 0.98, green: 0.47, blue: 0.42) // #FA786B
}

/// The whole type system: Faro for titles, Hanken Grotesk for everything else,
/// each on a short fixed scale. Screens pick a step, never a raw size.
enum QuietoFont {
    /// Faro steps. `hero` and `numeral` are for single words and big numbers
    /// shown alone (breathing phase, wordmark, counters).
    enum Heading: CGFloat {
        case numeral = 72, hero = 44, display = 34, title = 28, section = 21, card = 18
    }

    /// Hanken Grotesk steps. `figure` is for timers and counts shown large.
    enum Sans: CGFloat {
        case figure = 28, body = 16, callout = 15, subhead = 13, caption = 12, overline = 11
    }

    static func heading(_ style: Heading, weight: Font.Weight = .semibold) -> Font { heading(style.rawValue, weight: weight) }
    static func sans(_ style: Sans, weight: Font.Weight = .regular) -> Font { sans(style.rawValue, weight: weight) }

    /// Faro has a much taller x-height than the previous serif, so sizes are
    /// scaled down to keep layouts balanced. Prefer the `Heading` steps.
    static func heading(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Faro-BoldLucky"
        case .regular, .light, .thin, .ultraLight: name = "Faro-RegularLucky"
        default: name = "Faro-SemiBoldLucky"
        }
        return .custom(name, size: (size * 0.86).rounded(), relativeTo: .title)
    }

    /// Hanken Grotesk is a variable font: the weight is applied on its axis.
    /// Prefer the `Sans` steps.
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Hanken Grotesk", size: size, relativeTo: .body).weight(weight)
    }

    static let display = heading(.display)
    static let title = heading(.title)
    static let section = heading(.section)
    static let body = sans(.body)
    static let caption = sans(.caption)
}

/// Three corner radii, plus `Capsule()` for pills and buttons.
enum QuietoRadius {
    /// Thumbnails, chips, small tiles.
    static let small: CGFloat = 12
    /// Cards, rows, fields, sheets content.
    static let card: CGFloat = 18
    /// Large artwork (hero, player cover).
    static let hero: CGFloat = 26
}

enum QuietoMetrics {
    static let contentMaxWidth: CGFloat = 430
    static let cornerRadius: CGFloat = QuietoRadius.card
    /// Height of primary and secondary buttons.
    static let controlHeight: CGFloat = 54
    static let minimumTapTarget: CGFloat = 44
    /// Round mint play buttons: in a row, on a card, as the main control.
    static let playSmall: CGFloat = 40
    static let playMedium: CGFloat = 56
    static let playLarge: CGFloat = 72
}

enum QuietoSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

/// Night sky shared by every screen: dusk indigo at the top fading into deep
/// navy, two faint glows and a sparse field of stars in the upper half.
struct QuietoBackground: View {
    var showsStars = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: QuietoColor.backgroundDusk, location: 0),
                    .init(color: QuietoColor.background, location: 0.42),
                    .init(color: QuietoColor.backgroundDeep, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(colors: [QuietoColor.aurora.opacity(0.28), .clear], center: UnitPoint(x: 0.12, y: -0.04), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [QuietoColor.mint.opacity(0.13), .clear], center: UnitPoint(x: 0.92, y: 0.02), startRadius: 0, endRadius: 360)
            if showsStars {
                QuietoStarfield(animated: !reduceMotion)
                    .mask(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .white.opacity(0.5), location: 0.3), .init(color: .clear, location: 0.62)], startPoint: .top, endPoint: .bottom))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Deterministic star field drawn in a single Canvas pass. A few stars breathe
/// slowly; the rest are static so the sky stays calm.
struct QuietoStarfield: View {
    var animated = true
    var count = 90

    private struct Star { let x, y, radius, opacity, phase: Double; let twinkles: Bool }

    private var stars: [Star] {
        var seed: UInt64 = 0x51E7_0A11
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt32.max >> 1)
        }
        return (0..<count).map { _ in
            let size = next()
            return Star(x: next(), y: next(), radius: 0.4 + pow(size, 3) * 1.3, opacity: 0.25 + next() * 0.6, phase: next() * .pi * 2, twinkles: next() < 0.3)
        }
    }

    var body: some View {
        let stars = self.stars
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: !animated)) { context in
            let time = animated ? context.date.timeIntervalSinceReferenceDate : 0
            Canvas { canvas, size in
                for star in stars {
                    let breath = star.twinkles ? 0.55 + 0.45 * sin(time * 0.6 + star.phase) : 1
                    let rect = CGRect(x: star.x * size.width - star.radius, y: star.y * size.height - star.radius, width: star.radius * 2, height: star.radius * 2)
                    canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity * breath)))
                    if star.radius > 1.2 {
                        canvas.fill(Path(ellipseIn: rect.insetBy(dx: -star.radius * 2, dy: -star.radius * 2)), with: .color(.white.opacity(0.05 * breath)))
                    }
                }
            }
        }
    }
}

extension View {
    /// Translucent card surface: a faint top-lit fill and a hairline border that
    /// catches the light on its upper edge.
    func quietoSurface(cornerRadius: CGFloat = QuietoMetrics.cornerRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(
                LinearGradient(colors: [Color(red: 0.62, green: 0.76, blue: 1.0).opacity(0.13), Color(red: 0.62, green: 0.76, blue: 1.0).opacity(0.06)], startPoint: .top, endPoint: .bottom),
                in: shape
            )
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
    }

    /// Soft mint halo under primary actions.
    func quietoGlow(_ color: Color = QuietoColor.mint, radius: CGFloat = 16) -> some View {
        shadow(color: color.opacity(0.32), radius: radius, y: radius * 0.35)
    }
}

/// Press feedback for custom buttons: a slight sink and dim.
struct QuietoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct QuietoCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(QuietoSpacing.md)
            .foregroundStyle(QuietoColor.textPrimary)
            .quietoSurface()
    }
}

struct QuietoPrimaryButton: View {
    let title: String
    let systemImage: String?
    var accessibilityHint: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 15, weight: .semibold)) }
                Text(title.quietoLocalized).font(QuietoFont.sans(.body, weight: .semibold))
            }
            .foregroundStyle(QuietoColor.background)
            .frame(maxWidth: .infinity)
            .frame(minHeight: QuietoMetrics.controlHeight)
            .padding(.horizontal, 16)
            .background(QuietoColor.mintFill, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
            .quietoGlow()
        }
        .buttonStyle(QuietoPressStyle())
        .accessibilityHint((accessibilityHint ?? "").quietoLocalized)
    }
}

struct QuietoOutlineButton: View {
    let title: String
    let systemImage: String?
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 14, weight: .semibold)) }
                Text(title.quietoLocalized).font(QuietoFont.sans(.callout, weight: .semibold))
            }
            .foregroundStyle(role == .destructive ? QuietoColor.danger : QuietoColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: QuietoMetrics.controlHeight)
            .background(QuietoColor.textPrimary.opacity(0.04), in: Capsule())
            .overlay(Capsule().strokeBorder((role == .destructive ? QuietoColor.danger : QuietoColor.textPrimary).opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(QuietoPressStyle())
    }
}

extension View {
    func quietoSectionTitle() -> some View {
        self.font(QuietoFont.section).foregroundStyle(QuietoColor.textPrimary)
    }

    /// Small spaced capitals above a block (« TA PROCHAINE SÉANCE »).
    func quietoOverline() -> some View {
        self.font(QuietoFont.sans(.overline, weight: .semibold)).tracking(1.2).textCase(.uppercase)
    }

    /// Round mint play / pause control of one of the three standard sizes.
    func quietoPlayCircle(_ size: CGFloat) -> some View {
        self.foregroundStyle(QuietoColor.background)
            .frame(width: size, height: size)
            .background(QuietoColor.mintFill, in: Circle())
    }
}

struct QuietoAssetImage: View {
    let name: String
    let contentMode: ContentMode

    init(_ name: String, contentMode: ContentMode = .fit) {
        self.name = name
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Rectangle().fill(QuietoColor.surfaceRaised)
                    .overlay(Image(systemName: "photo").foregroundStyle(QuietoColor.textSecondary))
            }
        }
    }

    private func loadImage() -> UIImage? {
        if let image = UIImage(named: name) { return image }
        let fileExtension = name.split(separator: ".").last.map(String.init)
        let baseName = name.split(separator: ".").dropLast().joined(separator: ".")
        guard let fileExtension,
              let path = Bundle.main.path(forResource: baseName, ofType: fileExtension) else { return nil }
        return UIImage(contentsOfFile: path)
    }
}

struct LouaneMark: View {
    var size: CGFloat = 26
    var color: Color = QuietoColor.mint
    var body: some View {
        HStack(spacing: size * 0.12) {
            Capsule().fill(color).frame(width: size * 0.28, height: size * 0.78).rotationEffect(.degrees(28))
            Capsule().fill(color.opacity(0.72)).frame(width: size * 0.28, height: size * 0.78).rotationEffect(.degrees(-28))
        }.frame(width: size, height: size).accessibilityLabel("Symbole de Louane".quietoLocalized)
    }
}

/// True while a mini player floats above the tab bar, so screens with their own
/// bottom controls (Louane's composer) can make room for it.
private struct QuietoMiniPlayerVisibleKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var quietoMiniPlayerVisible: Bool {
        get { self[QuietoMiniPlayerVisibleKey.self] }
        set { self[QuietoMiniPlayerVisibleKey.self] = newValue }
    }
}
