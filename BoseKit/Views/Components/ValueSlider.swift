import SwiftUI

struct ValueSlider: View {
    let title: LocalizedStringResource
    let value: Double
    let range: ClosedRange<Double>
    var revision = 0
    var editingChanged: (Bool) -> Void = { _ in }
    let commit: (Double) -> Void

    var body: some View {
        DraftValue(value: value, revision: revision, editingChanged: editingChanged, commit: commit) { draft, onEditing in
            VStack(spacing: 8) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(draft.wrappedValue, format: .number.precision(.fractionLength(0)))
                        .monospacedDigit()
                }
                Slider(value: draft, in: range, step: 1, onEditingChanged: onEditing)
                    .accessibilityLabel(title)
            }
        }
    }
}
