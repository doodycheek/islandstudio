import AVFoundation

/// Keeps the app process alive in the background by looping silent audio
/// (mixes with your music, shows nothing on the lock screen).
/// This is what lets the app keep feeding animation frames to the island.
final class KeepAlive {
    static let shared = KeepAlive()

    private var player: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []
    private(set) var isActive = false

    private init() {}

    func start() {
        guard !isActive else { return }
        isActive = true

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("KeepAlive session error: \(error)")
        }

        if player == nil {
            player = try? AVAudioPlayer(data: Self.silentWAV())
            player?.numberOfLoops = -1
            player?.volume = 0.01
            player?.prepareToPlay()
        }
        player?.play()

        if observers.isEmpty {
            let nc = NotificationCenter.default
            // Resume after phone calls, Siri, alarms, etc.
            observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] note in
                guard let self, self.isActive,
                      let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw),
                      type == .ended else { return }
                self.resume()
            })
            observers.append(nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: nil, queue: .main) { [weak self] _ in
                guard let self, self.isActive else { return }
                self.player = nil
                self.isActive = false
                self.start()
            })
        }
    }

    func stop() {
        isActive = false
        player?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func resume() {
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
    }

    /// Builds a silent 16-bit mono WAV in memory, so no audio file is needed.
    static func silentWAV(seconds: Int = 2, sampleRate: Int = 8000) -> Data {
        let dataSize = UInt32(seconds * sampleRate * 2)
        var d = Data()
        func put(_ s: String) { d.append(contentsOf: Array(s.utf8)) }
        func put32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func put16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        put("RIFF"); put32(36 + dataSize); put("WAVE")
        put("fmt "); put32(16); put16(1); put16(1)
        put32(UInt32(sampleRate)); put32(UInt32(sampleRate * 2)); put16(2); put16(16)
        put("data"); put32(dataSize)
        d.append(Data(count: Int(dataSize)))
        return d
    }
}
