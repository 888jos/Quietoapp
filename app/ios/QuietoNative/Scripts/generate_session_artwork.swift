import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("Resources/Artwork", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let basePaths = [
    "Resources/Assets.xcassets/FeatureSession.imageset/feature-session.png",
    "Resources/Assets.xcassets/RecentSession.imageset/recent-session.png",
    "Resources/Assets.xcassets/StressSession.imageset/stress-session.png",
    "Resources/Assets.xcassets/ThoughtsSession.imageset/thoughts-session.png",
    "Resources/Assets.xcassets/EmotionSession.imageset/emotion-session.png",
    "Resources/Assets.xcassets/ExpressSession.imageset/express-session.png",
    "Resources/Artwork/ambience-campfire.png",
    "Resources/Artwork/ambience-forest.png",
    "Resources/Artwork/ambience-river.png",
    "Resources/Artwork/ambience-ocean.png",
    "Resources/Artwork/ambience-rain.png",
    "Resources/Artwork/need-sleep.png",
    "Resources/Artwork/need-eventStress.png",
    "Resources/Artwork/need-racingThoughts.png",
    "Resources/Artwork/need-focus.png",
    "Resources/Artwork/need-overwhelmed.png"
]

let sessionIDs = [
    "express_1", "express_2", "express_3", "express_4", "express_5", "express_6", "express_7", "express_8",
    "decouverte_1", "decouverte_2", "decouverte_3",
    "actualite_1", "actualite_2", "actualite_3", "actualite_4", "actualite_5",
    "stress_1", "stress_2", "stress_3", "stress_4", "stress_5",
    "sleep_1", "sleep_2", "sleep_3", "sleep_4", "sleep_5",
    "breathing_1", "breathing_2", "breathing_3", "breathing_4",
    "emotion_1", "emotion_2", "emotion_3", "emotion_4", "emotion_5",
    "new_body_scan_sleep", "new_nidra_pause", "new_soft_reset", "new_thoughts_on_clouds",
    "new_sensory_shelter", "new_focus_reset", "new_after_conflict", "new_box_breathing",
    "new_long_exhale", "new_walking_pause", "new_morning_window", "new_commute_boundary", "new_safe_place"
]

let bases = basePaths.compactMap { NSImage(contentsOf: root.appendingPathComponent($0)) }
guard bases.count == basePaths.count else { fatalError("A base illustration is missing") }

func seed(_ value: String) -> UInt64 {
    value.utf8.reduce(1469598103934665603) { ($0 ^ UInt64($1)) &* 1099511628211 }
}

for (index, id) in sessionIDs.enumerated() {
    var value = seed(id)
    func next() -> CGFloat {
        value = value &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(value % 10_000) / 10_000
    }

    let size = NSSize(width: 768, height: 768)
    let image = NSImage(size: size)
    image.lockFocus()

    let base = bases[(index * 7 + Int(value % UInt64(bases.count))) % bases.count]
    let zoom = 1.03 + next() * 0.22
    let drawSize = NSSize(width: size.width * zoom, height: size.height * zoom)
    let offset = NSPoint(x: -(drawSize.width - size.width) * next(), y: -(drawSize.height - size.height) * next())
    base.draw(in: NSRect(origin: offset, size: drawSize), from: .zero, operation: .sourceOver, fraction: 1)

    let tint = NSColor(calibratedHue: 0.47 + next() * 0.16, saturation: 0.28, brightness: 0.52, alpha: 0.12)
    tint.setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

    let motif = NSBezierPath()
    motif.lineWidth = 9 + next() * 11
    motif.lineCapStyle = .round
    motif.lineJoinStyle = .round
    let start = NSPoint(x: 80 + next() * 160, y: 110 + next() * 420)
    motif.move(to: start)
    for step in 1...3 {
        motif.curve(
            to: NSPoint(x: CGFloat(step) * 190 + next() * 100, y: 120 + next() * 520),
            controlPoint1: NSPoint(x: CGFloat(step) * 135, y: 80 + next() * 600),
            controlPoint2: NSPoint(x: CGFloat(step) * 165, y: 80 + next() * 600)
        )
    }
    NSColor(calibratedRed: 0.66, green: 0.90, blue: 0.84, alpha: 0.30).setStroke()
    motif.stroke()

    let circle = NSBezierPath(ovalIn: NSRect(x: 70 + next() * 520, y: 80 + next() * 520, width: 34 + next() * 52, height: 34 + next() * 52))
    NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.79, alpha: 0.48).setFill()
    circle.fill()

    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [.compressionFactor: 0.82]) else {
        fatalError("Unable to encode \(id)")
    }
    try png.write(to: output.appendingPathComponent("session-\(id).png"), options: .atomic)
}

print("Generated \(sessionIDs.count) unique session illustrations in \(output.path)")
