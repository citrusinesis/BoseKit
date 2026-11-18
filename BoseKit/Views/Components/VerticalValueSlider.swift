import SwiftUI
import AppKit

struct VerticalValueSlider: View {
    let title: LocalizedStringResource
    let value: Double
    let range: ClosedRange<Double>
    let revision: Int
    let editingChanged: (Bool) -> Void
    let commit: (Double) -> Void

    var body: some View {
        DraftValue(value: value, revision: revision, editingChanged: editingChanged, commit: commit) { draft, onEditing in
            VStack(spacing: 8) {
                Text(draft.wrappedValue, format: .number.precision(.fractionLength(0)))
                    .monospacedDigit()
                NativeVerticalSlider(value: draft, range: range, title: title, editingChanged: onEditing)
                    .frame(width: 32, height: 140)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct NativeVerticalSlider: NSViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let title: LocalizedStringResource
    let editingChanged: (Bool) -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.locale) private var locale

    func makeNSView(context: Context) -> TrackingSlider {
        let slider = TrackingSlider(frame: NSRect(x: 0, y: 0, width: 32, height: 140))
        slider.isVertical = true
        slider.isContinuous = true
        slider.target = slider
        slider.action = #selector(TrackingSlider.valueChanged)
        return slider
    }

    func updateNSView(_ slider: TrackingSlider, context: Context) {
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.numberOfTickMarks = Int(range.upperBound - range.lowerBound) + 1
        slider.allowsTickMarkValuesOnly = true
        slider.altIncrementValue = 1
        slider.isEnabled = isEnabled
        if !slider.isTrackingMouse { slider.doubleValue = value }
        var label = title
        label.locale = locale
        slider.setAccessibilityLabel(String(localized: label))
        slider.changeValue = { value = $0 }
        slider.editingChanged = editingChanged
    }

    final class TrackingSlider: NSSlider {
        var isTrackingMouse = false
        var changeValue: (Double) -> Void = { _ in }
        var editingChanged: (Bool) -> Void = { _ in }

        override func mouseDown(with event: NSEvent) {
            guard isEnabled else { return }
            isTrackingMouse = true
            editingChanged(true)
            defer {
                isTrackingMouse = false
                editingChanged(false)
            }
            super.mouseDown(with: event)
        }

        @objc func valueChanged() {
            if !isTrackingMouse { editingChanged(true) }
            doubleValue = doubleValue.rounded()
            changeValue(doubleValue)
            if !isTrackingMouse { editingChanged(false) }
        }
    }
}
