import Foundation
@testable import BoseKitEngine

actor ScriptedTransport: BMAPTransport {
    typealias Responder = @Sendable ([UInt8]) throws -> [[UInt8]]

    struct ScriptExhausted: Error {
        let write: [UInt8]
    }

    enum Event: Equatable {
        case wrote([UInt8])
        case delivered([UInt8])
    }

    private enum Behavior {
        case silent
        case responder(Responder)
        case script([[[UInt8]]])
    }

    private struct Waiter {
        let id: UUID
        let isSatisfied: @Sendable (_ writeCount: Int, _ isClosed: Bool) -> Bool
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let stream: AsyncThrowingStream<[UInt8], any Error>
    private let sink: AsyncThrowingStream<[UInt8], any Error>.Continuation
    private let gatesWrites: Bool
    private var behavior: Behavior
    private var gates: [CheckedContinuation<Void, Never>] = []
    private var waiters: [Waiter] = []
    private var activeWrites = 0
    private(set) var log: [Event] = []
    private(set) var isClosed = false
    private(set) var peakConcurrentWrites = 0

    var writes: [[UInt8]] {
        log.compactMap { event in
            if case .wrote(let bytes) = event { bytes } else { nil }
        }
    }

    init(responder: Responder? = nil, gatesWrites: Bool = false) {
        self.init(behavior: responder.map(Behavior.responder) ?? .silent, gatesWrites: gatesWrites)
    }

    init(script: [[[UInt8]]]) {
        self.init(behavior: .script(script), gatesWrites: false)
    }

    private init(behavior: Behavior, gatesWrites: Bool) {
        let pair = AsyncThrowingStream<[UInt8], any Error>.makeStream()
        stream = pair.stream
        sink = pair.continuation
        self.behavior = behavior
        self.gatesWrites = gatesWrites
    }

    func open() -> AsyncThrowingStream<[UInt8], any Error> { stream }

    func write(_ bytes: [UInt8]) async throws {
        guard !isClosed else { throw BoseError.disconnected }
        log.append(.wrote(bytes))
        activeWrites += 1
        peakConcurrentWrites = max(peakConcurrentWrites, activeWrites)
        defer { activeWrites -= 1 }
        for chunk in try replies(to: bytes) { deliver(chunk) }
        resumeSatisfiedWaiters()
        if gatesWrites { await withCheckedContinuation { gates.append($0) } }
    }

    func inject(_ bytes: [UInt8]) { deliver(bytes) }

    func completeWrite() {
        if !gates.isEmpty { gates.removeFirst().resume() }
    }

    func close() {
        isClosed = true
        sink.finish()
        for gate in gates { gate.resume() }
        gates.removeAll()
        resumeSatisfiedWaiters()
    }

    func waitForWrites(_ count: Int) async throws {
        try await wait { writeCount, _ in writeCount >= count }
    }

    func waitUntilClosed() async throws {
        try await wait { _, isClosed in isClosed }
    }

    private func deliver(_ bytes: [UInt8]) {
        log.append(.delivered(bytes))
        sink.yield(bytes)
    }

    private func replies(to bytes: [UInt8]) throws -> [[UInt8]] {
        switch behavior {
        case .silent:
            return []
        case .responder(let responder):
            return try responder(bytes)
        case .script(var remaining):
            guard !remaining.isEmpty else { throw ScriptExhausted(write: bytes) }
            let next = remaining.removeFirst()
            behavior = .script(remaining)
            return next
        }
    }

    private func wait(
        until isSatisfied: @escaping @Sendable (_ writeCount: Int, _ isClosed: Bool) -> Bool
    ) async throws {
        if isSatisfied(writes.count, isClosed) { return }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await register(id: id, isSatisfied: isSatisfied)
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    private func register(
        id: UUID,
        isSatisfied: @escaping @Sendable (_ writeCount: Int, _ isClosed: Bool) -> Bool
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            if Task.isCancelled {
                continuation.resume(throwing: CancellationError())
            } else {
                waiters.append(Waiter(id: id, isSatisfied: isSatisfied, continuation: continuation))
            }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    private func resumeSatisfiedWaiters() {
        var pending: [Waiter] = []
        for waiter in waiters {
            if waiter.isSatisfied(writes.count, isClosed) {
                waiter.continuation.resume()
            } else {
                pending.append(waiter)
            }
        }
        waiters = pending
    }
}
