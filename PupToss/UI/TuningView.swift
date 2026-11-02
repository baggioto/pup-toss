#if DEBUG
import SwiftUI
import UIKit

/// Debug-only sliders for every feel value. Changes apply live and are remembered between
/// launches; "Copy values" puts the current set on the clipboard to bake into `Tuning`'s defaults.
struct TuningView: View {
    @Bindable var model: GameModel
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Rolling") {
                    slider("Friction", \.friction, 100...800, step: 10, unit: "pt/s²")
                    slider("Drag", \.drag, 0...2, step: 0.05, unit: "/s")
                    slider("Curve strength", \.curve, 0...30, step: 0.5)
                    slider("Max spin", \.maxSpin, 0...20, step: 0.5, unit: "rad/s")
                    slider("Throw power", \.power, 0.5...1.6, step: 0.05, unit: "×")
                }
                Section("Bounces") {
                    slider("Noggin", \.nogginBounce, 0...1, step: 0.02)
                    slider("Hedge", \.hedgeBounce, 0...1, step: 0.02)
                    slider("Rocks", \.rockBounce, 0...1.2, step: 0.02)
                }
                Section("Merging") {
                    slider("Pup gap", \.pupGap, 0...60, step: 1, unit: "pt")
                    slider("Good Boy gap", \.goodBoyGap, 0...60, step: 1, unit: "pt")
                    slider("Merge while slower than", \.mergeSpeed, 0...200, step: 5, unit: "pt/s")
                }
                Section("Specials and lawn") {
                    slider("Bone pull", \.bonePull, 0...3, step: 0.1, unit: "×")
                    slider("Bulldog weight", \.bulldogWeight, 1...10, step: 0.5, unit: "×")
                    slider("Sand friction", \.sandFriction, 1...5, step: 0.1, unit: "×")
                    slider("Puddle friction", \.puddleFriction, 0.05...1, step: 0.05, unit: "×")
                }
                Section {
                    Button(copied ? "Copied" : "Copy values") { copy() }
                    Button("Reset to defaults", role: .destructive) { model.tuning = .standard }
                }
            }
            .navigationTitle("Tuning")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func slider(_ title: String, _ key: WritableKeyPath<Tuning, CGFloat>, _ range: ClosedRange<CGFloat>,
                        step: CGFloat, unit: String = "") -> some View {
        let changed = model.tuning[keyPath: key] != Tuning.standard[keyPath: key]
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(model.tuning[keyPath: key], specifier: step < 1 ? "%.2f" : "%.0f") \(unit)")
                    .monospacedDigit()
                    .foregroundStyle(changed ? .orange : .secondary)
            }
            Slider(value: $model.tuning[dynamicMember: key], in: range, step: step)
        }
    }

    private func copy() {
        let mirror = Mirror(reflecting: model.tuning)
        let lines = mirror.children.compactMap { child -> String? in
            guard let label = child.label, let value = child.value as? CGFloat else { return nil }
            return "var \(label): CGFloat = \(String(format: "%g", Double(value)))"
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
        copied = true
    }
}

#endif
