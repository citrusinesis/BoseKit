@testable import BoseKitEngine

@MainActor
final class FakeRFCOMMLink: RFCOMMLink {
    private struct Waiter {
        let isSatisfied: @MainActor (FakeRFCOMMLink) -> Bool
        let continuation: CheckedContinuation<Void, Never>
    }

    let channel = FakeRFCOMMChannel()
    var isBasebandConnected: Bool
    var connectFailure: BoseError?
    var openChannelFailure: BoseError?
    private(set) var connectRequests = 0
    private(set) var openedChannelIDs: [RFCOMMChannel] = []
    private var sink: RFCOMMEventSink?
    private var waiters: [Waiter] = []

    init(isBasebandConnected: Bool = true) {
        self.isBasebandConnected = isBasebandConnected
        channel.didChange = { [weak self] in self?.resumeSatisfiedWaiters() }
    }

    func connect(reportingTo sink: @escaping RFCOMMEventSink) throws(BoseError) -> BasebandConnection {
        connectRequests += 1
        self.sink = sink
        defer { resumeSatisfiedWaiters() }
        if let connectFailure { throw connectFailure }
        return isBasebandConnected ? .established : .pending
    }

    func openChannel(_ rfcommChannel: RFCOMMChannel, reportingTo sink: @escaping RFCOMMEventSink) throws(BoseError) -> any RFCOMMChannelHandle {
        openedChannelIDs.append(rfcommChannel)
        self.sink = sink
        defer { resumeSatisfiedWaiters() }
        if let openChannelFailure { throw openChannelFailure }
        return channel
    }

    func emit(_ event: RFCOMMEvent) {
        sink?(event)
    }

    func completeWrite(_ index: Int, _ result: Result<Void, BoseError> = .success(())) {
        emit(.writeCompleted(channel.writes[index].identifier, result))
    }

    func waitUntil(_ isSatisfied: @escaping @MainActor (FakeRFCOMMLink) -> Bool) async {
        if isSatisfied(self) { return }
        await withCheckedContinuation { waiters.append(Waiter(isSatisfied: isSatisfied, continuation: $0)) }
    }

    private func resumeSatisfiedWaiters() {
        let satisfied = waiters.filter { $0.isSatisfied(self) }
        waiters.removeAll { $0.isSatisfied(self) }
        for waiter in satisfied { waiter.continuation.resume() }
    }
}

@MainActor
final class FakeRFCOMMChannel: RFCOMMChannelHandle {
    struct Write {
        let identifier: RFCOMMWriteID
        let bytes: [UInt8]
    }

    var maximumTransmissionUnit = 127
    var isOpen = true
    var writeFailure: BoseError?
    var closeOutcome = ChannelCloseOutcome.awaitingClosedNotification
    private(set) var writes: [Write] = []
    private(set) var closeRequests = 0
    private(set) var isDetached = false
    var didChange: @MainActor () -> Void = {}

    func write(_ chunk: ArraySlice<UInt8>, identifier: RFCOMMWriteID) throws(BoseError) {
        defer { didChange() }
        if let writeFailure { throw writeFailure }
        writes.append(Write(identifier: identifier, bytes: Array(chunk)))
    }

    func close() -> ChannelCloseOutcome {
        closeRequests += 1
        didChange()
        return closeOutcome
    }

    func detach() {
        isDetached = true
        didChange()
    }
}
