import SwiftUI

extension String {
    var quietoLocalized: String { NSLocalizedString(self, comment: "") }
}

enum QuietoColor {
    static let background = Color(red: 0.063, green: 0.114, blue: 0.188) // #101D30
    static let surface = Color(red: 0.106, green: 0.176, blue: 0.263) // #1B2D43
    static let surfaceRaised = Color(red: 0.075, green: 0.137, blue: 0.216)
    static let mint = Color(red: 0.659, green: 0.898, blue: 0.835) // #A8E5D5
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.66)
    static let divider = Color.white.opacity(0.13)
}

enum QuietoFont {
    static func serif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Cormorant Garamond", size: size, relativeTo: .title)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Hanken Grotesk", size: size, relativeTo: .body)
    }

    static let display = serif(32, weight: .semibold)
    static let title = serif(27, weight: .semibold)
    static let section = serif(21, weight: .semibold)
    static let body = sans(16)
    static let caption = sans(13)
}

enum QuietoMetrics {
    static let contentMaxWidth: CGFloat = 430
    static let cornerRadius: CGFloat = 16
    static let controlHeight: CGFloat = 46
    static let minimumTapTarget: CGFloat = 44
}

enum QuietoSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

struct QuietoCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(QuietoSpacing.md)
            .foregroundStyle(QuietoColor.textPrimary)
            .background(QuietoColor.surface, in: RoundedRectangle(cornerRadius: QuietoMetrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: QuietoMetrics.cornerRadius, style: .continuous)
                    .stroke(QuietoColor.divider, lineWidth: 1)
            }
    }
}

struct QuietoPrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(QuietoFont.sans(16, weight: .semibold))
            }
            .foregroundStyle(QuietoColor.background)
            .frame(maxWidth: .infinity)
            .frame(minHeight: QuietoMetrics.controlHeight)
            .padding(.horizontal, 16)
            .background(QuietoColor.mint, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ouvre la séance")
    }
}

struct QuietoOutlineButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(QuietoFont.sans(15, weight: .medium))
                if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)) }
            }
            .foregroundStyle(QuietoColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .overlay(Capsule().stroke(QuietoColor.textPrimary.opacity(0.8), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

extension View {
    func quietoSectionTitle() -> some View {
        self.font(QuietoFont.section).foregroundStyle(QuietoColor.textPrimary)
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
        }.frame(width: size, height: size).accessibilityLabel("Symbole de Louane")
    }
}
