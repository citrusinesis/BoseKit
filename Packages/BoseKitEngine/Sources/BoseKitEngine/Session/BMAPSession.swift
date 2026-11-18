import Foundation

public actor BMAPSession {
    private struct Pending {
        let id: UUID
        let packet: BMAPPacket
        let rule: ResponseRule
        let timeout: Duration
        let continuation: CheckedContinuation<[BMAPPacket], any Error>
        var replies: [BMAPPacket] = []
    }

    private let transport: any BMAPTransport
    private var decoder = BMAPDecoder()
    private var queue: [Pending] = []
    private var active: Pending?
    private var reader: Task<Void, Never>?
    private var writer: Task<Void, Never>?
    private var writingID: UUID?
    private var quietGeneration = UUID()
    private var deadline: Task<Void, Never>?
    private var quietTimer: Task<Void, Never>?
    private var closed = false
    private var observers: [UUID: AsyncStream<BMAPPacket>.Continuation] = [:]

    private init(transport: any BMAPTransport) {
        self.transport = transport
    }

    public static func connect(transport: any BMAPTransport) async throws -> BMAPSession {
        do {
            let bytes = try await transport.open()
            try Task.checkCancellation()
            let session = BMAPSession(transport: transport)
            await session.listen(to: bytes)
            return session
        } catch {
            await transport.close()
            throw error
        }
    }

    private func listen(to bytes: AsyncThrowingStream<[UInt8], any Error>) {
        reader = Task { [weak self] in
            do {
                for try await chunk in bytes {
                    guard let self else { return }
                    try await self.receive(chunk)
                }
                await self?.fail(BoseError.disconnected)
            } catch {
                await self?.fail(error)
            }
        }
    }

    public func events() -> AsyncStream<BMAPPacket> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<BMAPPacket>.makeStream(bufferingPolicy: .bufferingNewest(256))
        guard !closed else {
            continuation.finish()
            return stream
        }
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return stream
    }

    private func removeObserver(_ id: UUID) { observers[id] = nil }

    public func execute<Value>(_ command: BMAPCommand<Value>) async throws -> Value {
        let id = UUID()
        let packets: [BMAPPacket] = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                guard !closed else {
                    continuation.resume(throwing: BoseError.disconnected)
                    return
                }
                queue.append(Pending(id: id, packet: command.packet, rule: command.rule,
                                     timeout: command.timeout, continuation: continuation))
                advance()
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
        return try command.decode(packets)
    }

    private func advance() {
        guard !closed, active == nil, writingID == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        active = next
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: next.timeout) } catch { return }
            await self?.expire(next.id)
        }
        writingID = next.id
        writer = Task { [weak self, transport] in
            do {
                try await transport.write(next.packet.bytes)
                await self?.writeFinished(next.id)
            } catch {
                await self?.writeFailed(next.id, error: error)
            }
        }
    }

    private func writeFinished(_ id: UUID) {
        guard writingID == id else { return }
        writingID = nil
        writer = nil
        if active == nil {
            deadline?.cancel()
            deadline = nil
        }
        advance()
    }

    private func writeFailed(_ id: UUID, error: any Error) async {
        guard writingID == id else { return }
        writingID = nil
        await fail(error)
    }

    private func expire(_ id: UUID) async {
        guard active?.id == id || writingID == id else { return }
        await fail(BoseError.timeout)
    }

    private func cancel(_ id: UUID) async {
        if active?.id == id {
            await fail(CancellationError())
        } else if let index = queue.firstIndex(where: { $0.id == id }) {
            queue.remove(at: index).continuation.resume(throwing: CancellationError())
        }
    }

    private func receive(_ bytes: [UInt8]) throws {
        guard !closed else { return }
        for packet in try decoder.append(bytes) {
            for observer in observers.values { observer.yield(packet) }
            guard var pending = active else { continue }
            if packet.operation == .error, packet.address == pending.packet.address {
                finish(.failure(BoseError.device(packet.address, code: packet.payload.first ?? 0)))
                continue
            }
            guard pending.rule.addresses.contains(packet.address),
                  pending.rule.accepts(packet) else { continue }
            guard packet.operation == .status || packet.operation == .result else { continue }
            pending.replies.append(packet)
            active = pending
            switch pending.rule.completion {
            case .first(let operators):
                if let operation = packet.operation, operators.contains(operation) {
                    finish(.success(pending.replies))
                }
            case .quiet(let duration):
                quietTimer?.cancel()
                if pending.rule.isComplete?(pending.replies) == true {
                    finish(.success(pending.replies))
                    continue
                }
                let id = pending.id
                let generation = UUID()
                quietGeneration = generation
                quietTimer = Task { [weak self] in
                    do { try await Task.sleep(for: duration) } catch { return }
                    await self?.finishCollection(id, generation: generation)
                }
            }
        }
        advance()
    }

    private func finishCollection(_ id: UUID, generation: UUID) {
        guard let pending = active, pending.id == id, generation == quietGeneration else { return }
        finish(.success(pending.replies))
        advance()
    }

    private func finish(_ result: Result<[BMAPPacket], any Error>) {
        guard let pending = active else { return }
        active = nil
        if writingID != pending.id {
            deadline?.cancel()
            deadline = nil
        }
        quietTimer?.cancel()
        quietTimer = nil
        pending.continuation.resume(with: result)
    }

    private func fail(_ error: any Error) async {
        guard !closed else {
            await transport.close()
            return
        }
        closed = true
        finish(.failure(error))
        for pending in queue { pending.continuation.resume(throwing: error) }
        queue.removeAll()
        reader?.cancel()
        writer?.cancel()
        deadline?.cancel()
        writingID = nil
        for observer in observers.values { observer.finish() }
        observers.removeAll()
        await transport.close()
    }

    public func close() async { await fail(BoseError.disconnected) }

    deinit {
        reader?.cancel()
        writer?.cancel()
        deadline?.cancel()
        quietTimer?.cancel()
        let transport = transport
        Task { await transport.close() }
    }
}
