import AVFoundation

/// Game sounds, synthesised in code at launch so the app ships no audio files. A small pool of
/// voices plays them with per-play volume and pitch, so repeated hits don't sound identical.
/// Uses the ambient audio session: it respects the silent switch and mixes with the player's music.
final class SoundEngine {
    enum Sound: CaseIterable {
        case bonk, thud, snap, tick, pop, fanfare, bark, chomp, splash, foul, goal, unlock, whistle, whoosh, squeak
    }

    static let shared = SoundEngine()

    var isEnabled = true

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var voices: [(player: AVAudioPlayerNode, varispeed: AVAudioUnitVarispeed)] = []
    private var nextVoice = 0
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var started = false

    private init() {
        for sound in Sound.allCases {
            buffers[sound] = Self.render(sound, format: format)
        }
        for _ in 0..<10 {
            let player = AVAudioPlayerNode()
            let varispeed = AVAudioUnitVarispeed()
            engine.attach(player)
            engine.attach(varispeed)
            engine.connect(player, to: varispeed, format: format)
            engine.connect(varispeed, to: engine.mainMixerNode, format: format)
            voices.append((player, varispeed))
        }
    }

    /// `pitch` is a playback-rate multiplier (1 = as rendered).
    func play(_ sound: Sound, volume: Float = 1, pitch: Float = 1) {
        guard isEnabled, let buffer = buffers[sound], startIfNeeded() else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.player.stop()
        voice.varispeed.rate = max(0.25, min(4, pitch))
        voice.player.volume = max(0, min(1, volume))
        voice.player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        voice.player.play()
    }

    private func startIfNeeded() -> Bool {
        if started && engine.isRunning { return true }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            started = true
            return true
        } catch {
            return false
        }
    }

    // MARK: - Synthesis

    private static func render(_ sound: Sound, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = Float(format.sampleRate)
        let samples = synthesize(sound, rate: rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for (i, sample) in samples.enumerated() { channel[i] = sample }
        return buffer
    }

    /// A deterministic noise source, so the sounds are the same on every launch.
    private struct Noise {
        var state: UInt32 = 0x9E37_79B9
        mutating func next() -> Float {
            state ^= state << 13; state ^= state >> 17; state ^= state << 5
            return Float(state) / Float(UInt32.max) * 2 - 1
        }
    }

    private static func synthesize(_ sound: Sound, rate: Float) -> [Float] {
        var noise = Noise()
        func tone(_ duration: Float, _ body: (_ t: Float, _ i: Int) -> Float) -> [Float] {
            (0..<Int(duration * rate)).map { i in body(Float(i) / rate, i) }
        }
        /// Sine whose frequency glides exponentially from `from` to `to` over `duration`.
        func glide(_ duration: Float, from: Float, to: Float, decay: Float, harmonics: Float = 0) -> [Float] {
            var phase: Float = 0
            return tone(duration) { t, _ in
                let f = from * pow(to / from, t / duration)
                phase += 2 * .pi * f / rate
                let wave = sin(phase) + harmonics * sin(2 * phase) + harmonics * 0.5 * sin(3 * phase)
                return wave * exp(-t / decay) * min(1, t * 400)
            }
        }
        func lowpassNoise(_ duration: Float, cutoff: Float, decay: Float, attack: Float = 0.002) -> [Float] {
            var last: Float = 0
            let a = exp(-2 * .pi * cutoff / rate)
            return tone(duration) { t, _ in
                last = (1 - a) * noise.next() + a * last
                return last * exp(-t / decay) * min(1, t / attack) * 3
            }
        }
        func mix(_ layers: [Float]...) -> [Float] {
            let length = layers.map(\.count).max() ?? 0
            return (0..<length).map { i in layers.reduce(0) { $0 + (i < $1.count ? $1[i] : 0) } }
        }
        func then(_ parts: [Float]...) -> [Float] { parts.flatMap { $0 } }
        func silence(_ duration: Float) -> [Float] { [Float](repeating: 0, count: Int(duration * rate)) }
        func normalize(_ samples: [Float], peak: Float = 0.8) -> [Float] {
            let top = samples.map(abs).max() ?? 1
            return top > 0 ? samples.map { $0 / top * peak } : samples
        }

        switch sound {
        case .bonk:
            return normalize(mix(glide(0.14, from: 430, to: 170, decay: 0.035, harmonics: 0.3),
                                 lowpassNoise(0.02, cutoff: 3000, decay: 0.004).map { $0 * 0.4 }))
        case .thud:
            return normalize(mix(glide(0.16, from: 170, to: 80, decay: 0.045),
                                 lowpassNoise(0.08, cutoff: 600, decay: 0.02).map { $0 * 0.6 }), peak: 0.7)
        case .snap:
            return normalize(mix(lowpassNoise(0.06, cutoff: 7000, decay: 0.008, attack: 0.0005),
                                 glide(0.05, from: 1900, to: 900, decay: 0.01).map { $0 * 0.5 }))
        case .tick:
            return normalize(glide(0.035, from: 900, to: 700, decay: 0.008), peak: 0.35)
        case .pop:
            return normalize(glide(0.18, from: 480, to: 1150, decay: 0.06, harmonics: 0.2))
        case .fanfare:
            let notes: [(Float, Float)] = [(523, 0.09), (659, 0.09), (784, 0.09), (1047, 0.34)]
            return normalize(then(notes.map { glide($0.1, from: $0.0, to: $0.0, decay: $0.1 * 0.8, harmonics: 0.35) }
                .reduce(into: [Float]()) { $0 += $1 }))
        case .bark:
            // "Wu-": a short low rising glide; "-f": a breathy falling burst.
            return normalize(then(
                mix(glide(0.07, from: 260, to: 420, decay: 0.08, harmonics: 0.8), lowpassNoise(0.07, cutoff: 1200, decay: 0.05).map { $0 * 0.25 }),
                mix(glide(0.13, from: 440, to: 210, decay: 0.05, harmonics: 0.9), lowpassNoise(0.13, cutoff: 1800, decay: 0.04).map { $0 * 0.35 })
            ))
        case .chomp:
            let crunch = lowpassNoise(0.05, cutoff: 1500, decay: 0.015)
            return normalize(then(crunch, silence(0.03), crunch, silence(0.03), crunch.map { $0 * 0.7 }))
        case .splash:
            var last: Float = 0
            let splash = lowpassNoise(0.35, cutoff: 2500, decay: 0.09, attack: 0.01).map { sample -> Float in
                // Take the low end out so it sounds like water, not wind.
                let high = sample - last
                last = sample
                return high * 4
            }
            return normalize(splash, peak: 0.55)
        case .foul:
            return normalize(then(glide(0.14, from: 330, to: 300, decay: 0.12, harmonics: 0.5),
                                  glide(0.26, from: 230, to: 150, decay: 0.15, harmonics: 0.5)), peak: 0.6)
        case .goal:
            return normalize(then(glide(0.11, from: 880, to: 880, decay: 0.12), glide(0.28, from: 1320, to: 1320, decay: 0.16)), peak: 0.6)
        case .whoosh:
            var last: Float = 0
            let gust = (0..<Int(0.7 * rate)).map { i -> Float in
                let t = Float(i) / rate
                last = 0.94 * last + 0.06 * noise.next()
                return last * sin(.pi * t / 0.7) * 6
            }
            return normalize(gust, peak: 0.5)
        case .squeak:
            let chirp = glide(0.05, from: 2600, to: 3400, decay: 0.03)
            return normalize(then(chirp, silence(0.05), chirp, silence(0.05), chirp), peak: 0.45)
        case .whistle:
            // Two-tone "fweet-fweeo" with a little vibrato.
            var phase: Float = 0
            func blow(_ duration: Float, from: Float, to: Float) -> [Float] {
                tone(duration) { t, _ in
                    let f = from * pow(to / from, t / duration) * (1 + 0.012 * sin(2 * .pi * 28 * t))
                    phase += 2 * .pi * f / rate
                    let edge = min(1, t * 60) * min(1, (duration - t) * 40)
                    return sin(phase) * edge
                }
            }
            return normalize(then(blow(0.16, from: 1700, to: 2300), silence(0.04), blow(0.26, from: 2300, to: 1600)), peak: 0.55)
        case .unlock:
            return normalize(then(glide(0.08, from: 660, to: 660, decay: 0.07, harmonics: 0.2),
                                  glide(0.08, from: 880, to: 880, decay: 0.07, harmonics: 0.2),
                                  glide(0.3, from: 1320, to: 1320, decay: 0.2, harmonics: 0.2)), peak: 0.6)
        }
    }
}
