import CoreHaptics
import UIKit

/// Core Haptics for the slingshot and impacts, falling back to simple impact feedback on devices
/// (and the simulator) without a haptic engine.
final class Haptics {
    private var engine: CHHapticEngine?
    private var stretchPlayer: CHHapticAdvancedPatternPlayer?
    private let fallback = UIImpactFeedbackGenerator(style: .soft)
    private let fallbackSnap = UIImpactFeedbackGenerator(style: .rigid)

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        engine?.playsHapticsOnly = true
    }

    var isRich: Bool { engine != nil }

    /// A low rumble that starts when the band is grabbed and builds with the pull.
    func beginStretch() {
        guard let engine, (try? engine.start()) != nil else { return }
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: 0,
            duration: 30
        )
        guard let pattern = try? CHHapticPattern(events: [rumble], parameters: []),
              let player = try? engine.makeAdvancedPlayer(with: pattern)
        else { return }
        stretchPlayer = player
        updateStretch(0)
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    /// `amount` is how far the band is pulled, from 0 to 1.
    func updateStretch(_ amount: CGFloat) {
        guard let stretchPlayer else { return }
        let amount = Float(min(max(amount, 0), 1))
        try? stretchPlayer.sendParameters([
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0.05 + 0.6 * amount * amount, relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: 0.1 + 0.3 * amount, relativeTime: 0),
        ], atTime: CHHapticTimeImmediate)
    }

    func endStretch() {
        try? stretchPlayer?.stop(atTime: CHHapticTimeImmediate)
        stretchPlayer = nil
    }

    /// The band letting go: a single sharp snap.
    func snap() {
        endStretch()
        if !transient(intensity: 1, sharpness: 1) {
            fallbackSnap.impactOccurred(intensity: 1)
        }
    }

    /// A dull thud scaled to how hard something hit. Hedge hits are duller than Noggin knocks.
    func thud(_ intensity: CGFloat, againstWall: Bool) {
        let strength = Float(0.3 + 0.7 * min(max(intensity, 0), 1))
        if !transient(intensity: strength, sharpness: againstWall ? 0.12 : 0.3) {
            fallback.impactOccurred(intensity: CGFloat(strength))
        }
    }

    /// For devices without Core Haptics: a light tick while the band stretches.
    func tick(_ intensity: CGFloat) {
        guard engine == nil else { return }
        fallback.impactOccurred(intensity: intensity)
    }

    @discardableResult
    private func transient(intensity: Float, sharpness: Float) -> Bool {
        guard let engine, (try? engine.start()) != nil else { return false }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
              let player = try? engine.makePlayer(with: pattern)
        else { return false }
        return (try? player.start(atTime: CHHapticTimeImmediate)) != nil
    }
}
