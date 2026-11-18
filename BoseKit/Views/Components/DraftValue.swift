import SwiftUI

struct DraftValue<Content: View>: View {
    let value: Double
    let revision: Int
    let editingChanged: (Bool) -> Void
    let commit: (Double) -> Void
    @ViewBuilder let content: (_ draft: Binding<Double>, _ editingChanged: @escaping (Bool) -> Void) -> Content

    @State private var draft = 0.0
    @State private var editing = false

    var body: some View {
        content($draft, handleEditing)
            .onAppear { draft = value }
            .onChange(of: value) { _, newValue in if !editing { draft = newValue } }
            .onChange(of: revision) { if !editing { draft = value } }
            .onDisappear { if editing { handleEditing(false) } }
    }

    private func handleEditing(_ active: Bool) {
        editing = active
        editingChanged(active)
        if !active && draft != value { commit(draft) }
    }
}
