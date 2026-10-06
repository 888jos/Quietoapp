import AVFoundation
import Foundation

enum QuietoSpeechRenderError: LocalizedError {
    case unavailable
    var errorDescription: String? { "La voix Apple n’est pas disponible pour le moment." }
}

/// Renders Apple's on-device speech synthesis to a seekable local CAF file.
/// Spoken phrases are separated by genuine PCM silence so the produced track
/// has the exact editorial duration advertised by the catalog.
final class QuietoSpeechRenderer {
    private static let cacheVersion = "v3-audible"
    private final class Job {
        let session: QuietoSession
        let url: URL
        let sentences: [String]
        let continuation: CheckedContinuation<URL, Error>
        var index = 0
        var file: AVAudioFile?
        var completed = false

        init(session: QuietoSession, url: URL, sentences: [String], continuation: CheckedContinuation<URL, Error>) {
            self.session = session
            self.url = url
            self.sentences = sentences
            self.continuation = continuation
        }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var activeJob: Job?

    func render(_ session: QuietoSession) async throws -> URL {
        guard session.readerMode == .guidedVoice else {
            throw QuietoSpeechRenderError.unavailable
        }
        let folder = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("QuietoNarrations-\(Self.cacheVersion)-\(QuietoLocalization.languageCode)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(session.id).caf")
        if FileManager.default.fileExists(atPath: url.path), Self.isAudibleAudioFile(at: url) { return url }
        try? FileManager.default.removeItem(at: url)

        let sentences = session.localizedTranscript
            .replacingOccurrences(of: "? ", with: "?\n")
            .replacingOccurrences(of: "! ", with: "!\n")
            .replacingOccurrences(of: ". ", with: ".\n")
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return try await withCheckedThrowingContinuation { continuation in
            let job = Job(session: session, url: url, sentences: sentences, continuation: continuation)
            activeJob = job
            renderNextSentence(for: job)
        }
    }

    private func renderNextSentence(for job: Job) {
        guard !job.completed else { return }
        guard job.index < job.sentences.count else { finish(job); return }

        let utterance = AVSpeechUtterance(string: job.sentences[job.index])
        utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceLanguage)
        utterance.rate = 0.43
        utterance.pitchMultiplier = 0.94

        synthesizer.write(utterance) { [weak self, weak job] buffer in
            guard let self, let job, !job.completed, let pcm = buffer as? AVAudioPCMBuffer else { return }
            do {
                if pcm.frameLength == 0 {
                    if job.index < job.sentences.count - 1, let file = job.file {
                        let wordCount = job.session.transcript.split(whereSeparator: \.isWhitespace).count
                        let estimatedSpeechSeconds = Double(wordCount) / 3.0
                        let pauseBudget = max(0, Double(job.session.durationMinutes * 60) - estimatedSpeechSeconds)
                        let pauseSeconds = min(35, max(2.5, pauseBudget / Double(max(1, job.sentences.count - 1))))
                        try self.appendSilence(seconds: pauseSeconds, to: file)
                    }
                    job.index += 1
                    self.renderNextSentence(for: job)
                    return
                }
                if job.file == nil { job.file = try AVAudioFile(forWriting: job.url, settings: pcm.format.settings) }
                try job.file?.write(from: pcm)
            } catch { self.fail(job, error: error) }
        }
    }

    private func finish(_ job: Job) {
        do {
            guard let file = job.file else { throw QuietoSpeechRenderError.unavailable }
            let targetFrames = AVAudioFramePosition(Double(job.session.durationMinutes * 60) * file.processingFormat.sampleRate)
            let remainingFrames = max(0, targetFrames - file.length)
            if remainingFrames > 0 { try appendSilence(frames: remainingFrames, to: file) }
            guard Self.isAudibleAudioFile(at: job.url) else { throw QuietoSpeechRenderError.unavailable }
            job.completed = true
            activeJob = nil
            job.continuation.resume(returning: job.url)
        } catch { fail(job, error: error) }
    }

    /// Rejects stale files that have a valid duration but contain only PCM silence.
    /// This is intentionally lightweight and samples at most the first 20 seconds.
    static func isAudibleAudioFile(at url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url) else { return false }
        let format = file.processingFormat
        let frames = AVAudioFrameCount(min(file.length, AVAudioFramePosition(format.sampleRate * 20)))
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return false }
        do { try file.read(into: buffer, frameCount: frames) } catch { return false }
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return false }
        var peak: Float = 0
        for channel in 0..<Int(format.channelCount) {
            for frame in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channels[channel][frame])) }
        }
        return peak > 0.001
    }

    private static var voiceLanguage: String {
        switch QuietoLocalization.languageCode {
        case "en": "en-US"
        case "es": "es-ES"
        case "de": "de-DE"
        case "ja": "ja-JP"
        case "ko": "ko-KR"
        default: "fr-FR"
        }
    }

    private func appendSilence(seconds: Double, to file: AVAudioFile) throws {
        try appendSilence(frames: AVAudioFramePosition(seconds * file.processingFormat.sampleRate), to: file)
    }

    private func appendSilence(frames: AVAudioFramePosition, to file: AVAudioFile) throws {
        var remaining = frames
        let chunk = AVAudioFrameCount(file.processingFormat.sampleRate * 5)
        while remaining > 0 {
            let count = AVAudioFrameCount(min(AVAudioFramePosition(chunk), remaining))
            guard let silence = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: count) else { throw QuietoSpeechRenderError.unavailable }
            silence.frameLength = count
            try file.write(from: silence)
            remaining -= AVAudioFramePosition(count)
        }
    }

    private func fail(_ job: Job, error: Error) {
        guard !job.completed else { return }
        job.completed = true
        activeJob = nil
        try? FileManager.default.removeItem(at: job.url)
        job.continuation.resume(throwing: error)
    }
}
