import Foundation
import AVFoundation
import CryptoKit
import SwiftUI
import AgentCore

/// Dočasný šifrovaný zvukový soubor (16 kHz mono, 16 bit).
/// Klíč existuje JEN v paměti – po skončení aplikace je soubor nečitelný; po zpracování se maže.
final class EncryptedAudioFile: @unchecked Sendable {
    let url: URL
    private let key = SymmetricKey(size: .bits256)
    private var handle: FileHandle?
    private var buffer: [Int16] = []
    private let lock = NSLock()
    private(set) var sampleCount = 0
    private let chunkSamples = 16_000 * 10   // 10 s na blok

    init() throws {
        url = AppPaths.tempDirectory.appendingPathComponent("rec-\(UUID().uuidString).oaenc")
        FileManager.default.createFile(atPath: url.path, contents: nil,
                                       attributes: [.protectionKey: FileProtectionType.completeUnlessOpen])
        AppPaths.excludeFromBackup(url)
        handle = try FileHandle(forWritingTo: url)
    }

    var duration: TimeInterval { Double(sampleCount) / 16_000 }

    func append(_ samples: [Float]) {
        lock.lock(); defer { lock.unlock() }
        buffer.reserveCapacity(buffer.count + samples.count)
        for s in samples { buffer.append(Int16(max(-1, min(1, s)) * 32767)) }
        sampleCount += samples.count
        if buffer.count >= chunkSamples { flushLocked() }
    }

    func finish() {
        lock.lock(); defer { lock.unlock() }
        flushLocked()
        try? handle?.close()
        handle = nil
    }

    private func flushLocked() {
        guard !buffer.isEmpty, let handle else { return }
        let data = buffer.withUnsafeBufferPointer { Data(buffer: $0) }
        buffer.removeAll(keepingCapacity: true)
        guard let sealed = try? AES.GCM.seal(data, using: key).combined else { return }
        var len = UInt32(sealed.count).bigEndian
        handle.write(Data(bytes: &len, count: 4))
        handle.write(sealed)
    }

    /// Čte zvuk po oknech (např. 5 minut) – kvůli paměti.
    func readWindows(windowSeconds: Int, _ body: ([Float], TimeInterval) async throws -> Void) async throws {
        let data = try Data(contentsOf: url)
        var pos = 0
        var window: [Float] = []
        let windowSamples = windowSeconds * 16_000
        var offset: TimeInterval = 0
        while pos + 4 <= data.count {
            let len = Int(data[pos..<pos + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.bigEndian)
            pos += 4
            guard pos + len <= data.count else { break }
            let box = try AES.GCM.SealedBox(combined: data[pos..<pos + len])
            pos += len
            let plain = try AES.GCM.open(box, using: key)
            plain.withUnsafeBytes { raw in
                let ints = raw.bindMemory(to: Int16.self)
                window.reserveCapacity(window.count + ints.count)
                for v in ints { window.append(Float(v) / 32767) }
            }
            if window.count >= windowSamples {
                try await body(window, offset)
                offset += Double(window.count) / 16_000
                window.removeAll(keepingCapacity: true)
            }
        }
        if !window.isEmpty { try await body(window, offset) }
    }

    func delete() {
        finish()
        try? FileManager.default.removeItem(at: url)
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}

/// Dlouhé nahrávání (přednáška, porada, rozhovor) – běží i při zamčeném telefonu.
@MainActor
final class LongRecorder: ObservableObject {
    enum State: Equatable { case idle, recording, paused, finished }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0
    @Published var kind: RecordingKind = .lecture
    @Published private(set) var startedAt: Date?
    private(set) var file: EncryptedAudioFile?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var timer: Timer?
    private var interruptionObserver: NSObjectProtocol?
    private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

    var isActive: Bool { state == .recording || state == .paused }

    func start() async throws {
        guard state == .idle || state == .finished else { return }
        guard await AudioRecorder.requestPermission() else { throw SpeechError.micDenied }
        file?.delete()
        let f = try EncryptedAudioFile()
        file = f
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let conv = AVAudioConverter(from: format, to: target)
        converter = conv
        let tgt = target
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak self] buffer, _ in
            guard let conv else { return }
            // Převod synchronně (buffer se po návratu recykluje)
            let cap = AVAudioFrameCount(Double(buffer.frameLength) * tgt.sampleRate / buffer.format.sampleRate + 64)
            guard let out = AVAudioPCMBuffer(pcmFormat: tgt, frameCapacity: cap) else { return }
            var consumed = false
            var err: NSError?
            conv.convert(to: out, error: &err) { _, status in
                if consumed { status.pointee = .noDataNow; return nil }
                consumed = true; status.pointee = .haveData; return buffer
            }
            guard let ch = out.floatChannelData?[0] else { return }
            let samples = Array(UnsafeBufferPointer(start: ch, count: Int(out.frameLength)))
            f.append(samples)
            var sum: Float = 0
            for s in samples { sum += s * s }
            let lvl = samples.isEmpty ? 0 : min(1, sqrt(sum / Float(samples.count)) * 8)
            Task { @MainActor in self?.level = lvl }
        }
        engine.prepare()
        try engine.start()
        startedAt = Date()
        state = .recording
        startTimer()
        observeInterruptions()
    }

    func pause() {
        guard state == .recording else { return }
        engine.pause()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
        state = .recording
    }

    func stop() {
        guard isActive else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        timer?.invalidate(); timer = nil
        if let o = interruptionObserver { NotificationCenter.default.removeObserver(o) }
        interruptionObserver = nil
        file?.finish()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        level = 0
        state = .finished
    }

    /// Zahodí nahrávku (smaže šifrovaný soubor).
    func discard() {
        if isActive { stop() }
        file?.delete()
        file = nil
        elapsed = 0
        state = .idle
    }

    /// Nahrávka ze souboru (např. Diktafon) – převede se do stejného šifrovaného formátu.
    func importAudio(from url: URL) async throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        file?.delete()
        let f = try EncryptedAudioFile()
        let tgt = target
        try await Task.detached(priority: .userInitiated) {
            let input = try AVAudioFile(forReading: url)
            let fmt = input.processingFormat
            guard let conv = AVAudioConverter(from: fmt, to: tgt) else { throw SpeechError.noModel }
            let frames: AVAudioFrameCount = 16_384
            while true {
                guard let inBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { break }
                try input.read(into: inBuf, frameCount: frames)
                if inBuf.frameLength == 0 { break }
                let cap = AVAudioFrameCount(Double(inBuf.frameLength) * tgt.sampleRate / fmt.sampleRate + 64)
                guard let out = AVAudioPCMBuffer(pcmFormat: tgt, frameCapacity: cap) else { break }
                var consumed = false
                var err: NSError?
                conv.convert(to: out, error: &err) { _, status in
                    if consumed { status.pointee = .noDataNow; return nil }
                    consumed = true; status.pointee = .haveData; return inBuf
                }
                if let ch = out.floatChannelData?[0] {
                    f.append(Array(UnsafeBufferPointer(start: ch, count: Int(out.frameLength))))
                }
            }
            f.finish()
        }.value
        file = f
        elapsed = f.duration
        startedAt = Date()
        state = .finished
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .recording else { return }
                self.elapsed = self.file?.duration ?? 0
            }
        }
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            Task { @MainActor in
                if type == .began { self?.pause() }
                else { self?.resume() }   // po hovoru pokračujeme
            }
        }
    }
}
