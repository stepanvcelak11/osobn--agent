import Foundation
import AVFoundation
import SwiftUI

/// Sběr zvuku z mikrofonu – běží synchronně ve vlákně audio tapu (buffery se po návratu recyklují).
final class PCMCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    var onLevel: ((Float) -> Void)?

    func reset(inputFormat: AVAudioFormat) {
        lock.lock(); defer { lock.unlock() }
        samples.removeAll(keepingCapacity: true)
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        if let ch = buffer.floatChannelData?[0] {
            var sum: Float = 0
            let n = Int(buffer.frameLength)
            for i in 0..<n { sum += ch[i] * ch[i] }
            onLevel?(n > 0 ? min(1, sqrt(sum / Float(n)) * 8) : 0)
        }
        lock.lock(); defer { lock.unlock() }
        guard let converter else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }
        var consumed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        if let ch = out.floatChannelData?[0] {
            samples.append(contentsOf: UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
        }
    }

    func take() -> [Float] {
        lock.lock(); defer { lock.unlock() }
        let out = samples
        samples.removeAll()
        converter = nil
        return out
    }
}

/// Nahrávání z mikrofonu do paměti (16 kHz mono float pro Whisper). Nic se neukládá na disk.
@MainActor
final class AudioRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var level: Float = 0
    @Published private(set) var elapsed: TimeInterval = 0

    private let engine = AVAudioEngine()
    private let collector = PCMCollector()
    private var startDate: Date?
    private var timer: Timer?
    private let maxSeconds: TimeInterval = 90

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    func start() async throws {
        guard !isRecording else { return }
        guard await Self.requestPermission() else { throw SpeechError.micDenied }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true, options: [])

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        collector.reset(inputFormat: inFormat)
        collector.onLevel = { [weak self] l in Task { @MainActor in self?.level = l } }
        let collector = self.collector
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { buffer, _ in
            collector.process(buffer)
        }
        engine.prepare()
        try engine.start()
        isRecording = true
        startDate = Date()
        elapsed = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let s = self.startDate else { return }
                self.elapsed = Date().timeIntervalSince(s)
                if self.elapsed > self.maxSeconds { _ = self.stop() }
            }
        }
    }

    /// Ukončí nahrávání a vrátí zvuk (jen v paměti).
    @discardableResult
    func stop() -> [Float] {
        guard isRecording else { return [] }
        timer?.invalidate(); timer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        return collector.take()
    }

    func cancel() { _ = stop() }
}

/// Čtení odpovědí nahlas – systémová syntéza řeči iOS běží v zařízení (stažené hlasy).
@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    static var czechVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("cs") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        stop()
        let u = AVSpeechUtterance(string: text)
        let preferred = UserDefaults.standard.string(forKey: "tts.voice")
        u.voice = Self.czechVoices.first { $0.identifier == preferred } ?? Self.czechVoices.first ?? AVSpeechSynthesisVoice(language: "cs-CZ")
        let rate = UserDefaults.standard.object(forKey: "tts.rate") as? Float ?? 0.5
        u.rate = AVSpeechUtteranceMinimumSpeechRate + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate) * rate
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        isSpeaking = true
        synth.speak(u)
    }

    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }
}
