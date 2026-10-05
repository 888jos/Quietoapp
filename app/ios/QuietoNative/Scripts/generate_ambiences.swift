import Foundation

let sampleRate = 22_050
let duration = 30
let frameCount = sampleRate * duration
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = root.appendingPathComponent("Resources/Ambiences", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

struct Generator {
    var state: UInt64
    mutating func random() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 2_000_001) / 1_000_000 - 1
    }
}

func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
}

func writeWAV(name: String, seed: UInt64, render: (Int, Double, inout Generator, inout Double, inout Double) -> Double) throws -> URL {
    var pcm = Data(capacity: frameCount * 2)
    var random = Generator(state: seed)
    var low = 0.0
    var slower = 0.0
    for frame in 0..<frameCount {
        let time = Double(frame) / Double(sampleRate)
        let sample = max(-0.94, min(0.94, render(frame, time, &random, &low, &slower)))
        appendLE(Int16(sample * Double(Int16.max)), to: &pcm)
    }

    var wav = Data()
    wav.append("RIFF".data(using: .ascii)!)
    appendLE(UInt32(36 + pcm.count), to: &wav)
    wav.append("WAVEfmt ".data(using: .ascii)!)
    appendLE(UInt32(16), to: &wav)
    appendLE(UInt16(1), to: &wav)
    appendLE(UInt16(1), to: &wav)
    appendLE(UInt32(sampleRate), to: &wav)
    appendLE(UInt32(sampleRate * 2), to: &wav)
    appendLE(UInt16(2), to: &wav)
    appendLE(UInt16(16), to: &wav)
    wav.append("data".data(using: .ascii)!)
    appendLE(UInt32(pcm.count), to: &wav)
    wav.append(pcm)
    let url = output.appendingPathComponent("\(name).wav")
    try wav.write(to: url, options: .atomic)
    return url
}

let files: [(String, UInt64, (Int, Double, inout Generator, inout Double, inout Double) -> Double)] = [
    ("ambience-white-noise", 11, { _, _, rng, low, _ in
        let n = rng.random(); low += 0.02 * (n - low); return 0.23 * n + 0.04 * low
    }),
    ("ambience-pink-noise", 22, { _, _, rng, low, slower in
        let n = rng.random(); low += 0.08 * (n - low); slower += 0.004 * (n - slower); return 0.13 * n + 0.18 * low + 0.22 * slower
    }),
    ("ambience-campfire", 33, { frame, _, rng, low, slower in
        let n = rng.random(); low += 0.03 * (n - low); slower += 0.002 * (n - slower)
        let pop = frame % 12_731 < 70 ? exp(-Double(frame % 12_731) / 16) * 0.45 * rng.random() : 0
        return 0.09 * n + 0.18 * low + 0.16 * slower + pop
    }),
    ("ambience-forest", 44, { frame, time, rng, low, slower in
        let n = rng.random(); low += 0.006 * (n - low); slower += 0.0008 * (n - slower)
        let local = frame % 91_337
        let bird = local < 2_800 ? sin(2 * .pi * (1_100 + 500 * sin(time * 4)) * time) * sin(.pi * Double(local) / 2_800) * 0.10 : 0
        return 0.12 * low + 0.20 * slower + bird
    }),
    ("ambience-river", 55, { _, _, rng, low, slower in
        let n = rng.random(); low += 0.12 * (n - low); slower += 0.012 * (low - slower); return 0.13 * (n - low) + 0.24 * low + 0.16 * slower
    }),
    ("ambience-ocean", 66, { _, time, rng, low, slower in
        let n = rng.random(); low += 0.035 * (n - low); slower += 0.003 * (low - slower)
        let wave = 0.32 + 0.68 * pow((sin(time * .pi / 4.8) + 1) / 2, 1.8)
        return wave * (0.12 * n + 0.28 * low + 0.18 * slower)
    }),
    ("ambience-rain", 77, { frame, _, rng, low, _ in
        let n = rng.random(); low += 0.16 * (n - low)
        let drop = frame % 5_183 < 45 ? exp(-Double(frame % 5_183) / 10) * 0.32 : 0
        return 0.19 * (n - low) + 0.08 * low + drop
    }),
    ("ambience-night", 88, { frame, time, rng, low, slower in
        let n = rng.random(); low += 0.01 * (n - low); slower += 0.001 * (low - slower)
        let pulse = max(0, sin(time * 2.7))
        let insect = sin(2 * .pi * (3_400 + 90 * sin(time * 0.6)) * time) * pulse * 0.045
        let chirp = frame % 104_729 < 1_900 ? sin(2 * .pi * 2_100 * time) * sin(.pi * Double(frame % 104_729) / 1_900) * 0.07 : 0
        return 0.10 * slower + insect + chirp
    })
]

for (name, seed, renderer) in files {
    let wav = try writeWAV(name: name, seed: seed, render: renderer)
    let mp3 = output.appendingPathComponent("\(name).mp3")
    let process = Process()
    let lame = ["/opt/homebrew/bin/lame", "/usr/local/bin/lame"].first { FileManager.default.fileExists(atPath: $0) }
    guard let lame else { fatalError("Install the open-source LAME encoder with `brew install lame` to regenerate ambience MP3 files") }
    process.executableURL = URL(fileURLWithPath: lame)
    process.arguments = ["--silent", "--preset", "standard", wav.path, mp3.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { fatalError("afconvert failed for \(name)") }
    try FileManager.default.removeItem(at: wav)
    print("Generated \(mp3.lastPathComponent)")
}
