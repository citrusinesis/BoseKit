@MainActor
final class ActionQueue {
    private var pending = 0
    private var turns: [CheckedContinuation<Void, Never>] = []

    var isEmpty: Bool { pending == 0 }

    func enter() async {
        pending += 1
        guard pending > 1 else { return }
        await withCheckedContinuation { turns.append($0) }
    }

    func leave() {
        pending -= 1
        if !turns.isEmpty { turns.removeFirst().resume() }
    }
}
