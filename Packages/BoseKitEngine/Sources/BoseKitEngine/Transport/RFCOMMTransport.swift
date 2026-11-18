import Foundation

@MainActor
public final class RFCOMMTransport: BMAPTransport {
    private typealias State = RFCOMMTransportState

    private let rfcommChannel: RFCOMMChannel
    private let timings: RFCOMMTransportTimings
    private let link: any RFCOMMLink
    private let stream: AsyncThrowingStream<[UInt8], any Error>
    private let incoming: AsyncThrowingStream<[UInt8], any Error>.Continuation
    private var state = State.idle

    public convenience init(address: String, channel: RFCOMMChannel, closeSettlement: Duration = .milliseconds(150)) {
        self.init(channel: channel, timings: .standard(closeSettlement: closeSettlement),
                  link: IOBluetoothRFCOMMLink(address: address))
    }

    init(channel: RFCOMMChannel, timings: RFCOMMTransportTimings, link: any RFCOMMLink) {
        rfcommChannel = channel
        self.timings = timings
        self.link = link
        (stream, incoming) = AsyncThrowingStream<[UInt8], any Error>.makeStream()
    }

    private var eventSink: RFCOMMEventSink {
        { [weak self] event in self?.handle(event) }
    }

    @MainActor public func open() async throws -> AsyncThrowingStream<[UInt8], any Error> {
        guard case .idle = state else { throw BoseError.disconnected }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { beginOpening($0) }
        } onCancel: {
            Task { @MainActor [weak self] in self?.openCancelled() }
        }
    }

    @MainActor public func write(_ bytes: [UInt8]) async throws {
        try Task.checkCancellation()
        let channel = try writableChannel()
        guard bytes.count <= BMAPPacket.maximumLength else { throw BoseError.invalidArgument("BMAP packet size") }
        let chunkLength = max(1, channel.maximumTransmissionUnit)
        try await withTaskCancellationHandler {
            for offset in stride(from: 0, to: bytes.count, by: chunkLength) {
                try Task.checkCancellation()
                let chunk = bytes[offset..<min(offset + chunkLength, bytes.count)]
                try await withCheckedThrowingContinuation { send(chunk, completion: $0) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.writeCancelled() }
        }
    }

    @MainActor public func close() async {
        terminate(BoseError.disconnected)
        await withCheckedContinuation { awaitTeardown($0) }
    }

    private func beginOpening(_ continuation: State.OpenContinuation) {
        switch state {
        case .idle:
            break
        case .connecting, .open, .closing, .closed:
            continuation.resume(throwing: BoseError.disconnected)
            return
        }
        guard !Task.isCancelled else {
            state = .closed
            incoming.finish(throwing: CancellationError())
            continuation.resume(throwing: CancellationError())
            return
        }
        let deadline = schedule(after: timings.openDeadline) { $0.openDeadlinePassed() }
        do {
            let step: State.Connecting.Step = switch try link.connect(reportingTo: eventSink) {
            case .established: .awaitingChannel(try link.openChannel(rfcommChannel, reportingTo: eventSink))
            case .pending: .awaitingBaseband
            }
            state = .connecting(State.Connecting(step: step, continuation: continuation, deadline: deadline))
        } catch {
            deadline.cancel()
            state = .closed
            incoming.finish(throwing: error)
            continuation.resume(throwing: error)
        }
    }

    private func writableChannel() throws(BoseError) -> any RFCOMMChannelHandle {
        switch state {
        case .open(let open) where open.channel.isOpen:
            return open.channel
        case .idle, .connecting, .open, .closing, .closed:
            throw BoseError.disconnected
        }
    }

    private func send(_ chunk: ArraySlice<UInt8>, completion: CheckedContinuation<Void, any Error>) {
        switch state {
        case .open(var open):
            let identifier = open.register(completion) { identifier in
                schedule(after: timings.writeChunkDeadline) { $0.writeDeadlinePassed(identifier) }
            }
            state = .open(open)
            do {
                try open.channel.write(chunk, identifier: identifier)
            } catch {
                terminate(error)
            }
        case .idle, .connecting, .closing, .closed:
            completion.resume(throwing: BoseError.disconnected)
        }
    }

    private func awaitTeardown(_ waiter: CheckedContinuation<Void, Never>) {
        switch state {
        case .closing(var closing):
            closing.waiters.append(waiter)
            state = .closing(closing)
        case .idle, .connecting, .open, .closed:
            waiter.resume()
        }
    }

    private func handle(_ event: RFCOMMEvent) {
        switch event {
        case .basebandConnected(let result): basebandConnected(result)
        case .channelOpened(let result): channelOpened(result)
        case .received(let bytes): received(bytes)
        case .writeCompleted(let identifier, let result): writeCompleted(identifier, result)
        case .channelClosed: channelClosed()
        }
    }

    private func basebandConnected(_ result: Result<Void, BoseError>) {
        switch state {
        case .connecting(var connecting):
            switch connecting.step {
            case .awaitingBaseband:
                do {
                    try result.get()
                    connecting.step = .awaitingChannel(try link.openChannel(rfcommChannel, reportingTo: eventSink))
                    state = .connecting(connecting)
                } catch {
                    terminate(error)
                }
            case .awaitingChannel:
                return
            }
        case .idle, .open, .closing, .closed:
            return
        }
    }

    private func channelOpened(_ result: Result<Void, BoseError>) {
        switch state {
        case .connecting(let connecting):
            switch (connecting.step, result) {
            case (.awaitingChannel(let channel), .success):
                connecting.deadline.cancel()
                state = .open(State.Open(channel: channel))
                connecting.continuation.resume(returning: stream)
            case (.awaitingChannel, .failure(let error)):
                terminate(error)
            case (.awaitingBaseband, _):
                return
            }
        case .closing(let closing):
            _ = closing.channel.close()
        case .idle, .open, .closed:
            return
        }
    }

    private func received(_ bytes: [UInt8]) {
        switch state {
        case .connecting(let connecting):
            switch connecting.step {
            case .awaitingChannel: incoming.yield(bytes)
            case .awaitingBaseband: return
            }
        case .open:
            incoming.yield(bytes)
        case .idle, .closing, .closed:
            return
        }
    }

    private func writeCompleted(_ identifier: RFCOMMWriteID, _ result: Result<Void, BoseError>) {
        switch state {
        case .open(var open):
            guard let pending = open.pendingWrites.removeValue(forKey: identifier) else { return }
            state = .open(open)
            pending.deadline.cancel()
            switch result {
            case .success:
                pending.continuation.resume()
            case .failure(let error):
                pending.continuation.resume(throwing: error)
                terminate(error)
            }
        case .idle, .connecting, .closing, .closed:
            return
        }
    }

    private func channelClosed() {
        switch state {
        case .connecting(let connecting):
            switch connecting.step {
            case .awaitingChannel(let channel):
                abandon(connecting, with: BoseError.disconnected)
                channel.detach()
                state = .closed
            case .awaitingBaseband:
                return
            }
        case .open(let open):
            abandon(open, with: BoseError.disconnected)
            open.channel.detach()
            state = .closed
        case .closing(var closing):
            switch closing.phase {
            case .awaitingClosedNotification(let fallback):
                fallback.cancel()
                closing.phase = .settling(schedule(after: timings.closeSettlement) { $0.closeSettlementElapsed() })
                state = .closing(closing)
            case .settling:
                return
            }
        case .idle, .closed:
            return
        }
    }

    private func openCancelled() {
        switch state {
        case .connecting:
            terminate(CancellationError())
        case .idle, .open, .closing, .closed:
            return
        }
    }

    private func writeCancelled() {
        switch state {
        case .open:
            terminate(CancellationError())
        case .idle, .connecting, .closing, .closed:
            return
        }
    }

    private func openDeadlinePassed() {
        switch state {
        case .connecting:
            terminate(BoseError.timeout)
        case .idle, .open, .closing, .closed:
            return
        }
    }

    private func writeDeadlinePassed(_ identifier: RFCOMMWriteID) {
        switch state {
        case .open(let open) where open.pendingWrites[identifier] != nil:
            terminate(BoseError.timeout)
        case .idle, .connecting, .open, .closing, .closed:
            return
        }
    }

    private func closeFallbackElapsed() {
        switch state {
        case .closing(let closing):
            switch closing.phase {
            case .awaitingClosedNotification: finishClosing(closing)
            case .settling: return
            }
        case .idle, .connecting, .open, .closed:
            return
        }
    }

    private func closeSettlementElapsed() {
        switch state {
        case .closing(let closing):
            switch closing.phase {
            case .settling: finishClosing(closing)
            case .awaitingClosedNotification: return
            }
        case .idle, .connecting, .open, .closed:
            return
        }
    }

    private func terminate(_ error: any Error) {
        switch state {
        case .idle:
            state = .closed
            incoming.finish(throwing: error)
        case .connecting(let connecting):
            abandon(connecting, with: error)
            switch connecting.step {
            case .awaitingBaseband: state = .closed
            case .awaitingChannel(let channel): beginClosing(channel)
            }
        case .open(let open):
            abandon(open, with: error)
            beginClosing(open.channel)
        case .closing, .closed:
            return
        }
    }

    private func abandon(_ connecting: State.Connecting, with error: any Error) {
        connecting.deadline.cancel()
        connecting.continuation.resume(throwing: error)
        incoming.finish(throwing: error)
    }

    private func abandon(_ open: State.Open, with error: any Error) {
        for pending in open.pendingWrites.values {
            pending.deadline.cancel()
            pending.continuation.resume(throwing: error)
        }
        incoming.finish(throwing: error)
    }

    private func beginClosing(_ channel: any RFCOMMChannelHandle) {
        switch channel.close() {
        case .awaitingClosedNotification:
            let fallback = schedule(after: timings.closeFallback) { $0.closeFallbackElapsed() }
            state = .closing(State.Closing(channel: channel, phase: .awaitingClosedNotification(fallback: fallback)))
        case .completed:
            channel.detach()
            state = .closed
        }
    }

    private func finishClosing(_ closing: State.Closing) {
        closing.phase.timer.cancel()
        closing.channel.detach()
        state = .closed
        for waiter in closing.waiters { waiter.resume() }
    }

    private func schedule(after delay: Duration,
                          _ expire: @escaping @MainActor (RFCOMMTransport) -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            do { try await Task.sleep(for: delay) } catch { return }
            guard let self, !Task.isCancelled else { return }
            expire(self)
        }
    }
}
