import Testing
@testable import BoseKitEngine

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RFCOMMTransportTests {
    private static let channelID: RFCOMMChannel = 8

    private func makeTransport(_ link: FakeRFCOMMLink,
                               timings: RFCOMMTransportTimings = .patient) -> RFCOMMTransport {
        RFCOMMTransport(channel: Self.channelID, timings: timings, link: link)
    }

    private func openTransport(_ link: FakeRFCOMMLink,
                               timings: RFCOMMTransportTimings = .patient) async throws
        -> (RFCOMMTransport, AsyncThrowingStream<[UInt8], any Error>) {
        let transport = makeTransport(link, timings: timings)
        let opening = Task { try await transport.open() }
        await link.waitUntil { $0.openedChannelIDs.count == 1 }
        link.emit(.channelOpened(.success(())))
        return (transport, try await opening.value)
    }

    @Test func opensChannelOnAlreadyConnectedDevice() async throws {
        let link = FakeRFCOMMLink(isBasebandConnected: true)
        let (transport, _) = try await openTransport(link)
        #expect(link.openedChannelIDs == [Self.channelID])
        #expect(link.connectRequests == 1)
        link.channel.closeOutcome = .completed
        await transport.close()
    }

    @Test func opensChannelAfterBasebandConnects() async throws {
        let link = FakeRFCOMMLink(isBasebandConnected: false)
        let transport = makeTransport(link)
        let opening = Task { try await transport.open() }
        await link.waitUntil { $0.connectRequests == 1 }
        #expect(link.openedChannelIDs.isEmpty)
        link.emit(.basebandConnected(.success(())))
        #expect(link.openedChannelIDs == [Self.channelID])
        link.emit(.channelOpened(.success(())))
        _ = try await opening.value
    }

    @Test func connectFailureFailsOpen() async {
        let link = FakeRFCOMMLink(isBasebandConnected: false)
        link.connectFailure = .transport(-7)
        let transport = makeTransport(link)
        await #expect(throws: BoseError.transport(-7)) { try await transport.open() }
        #expect(link.openedChannelIDs.isEmpty)
    }

    @Test func basebandFailureFailsOpen() async {
        let link = FakeRFCOMMLink(isBasebandConnected: false)
        let transport = makeTransport(link)
        let opening = Task { try await transport.open() }
        await link.waitUntil { $0.connectRequests == 1 }
        link.emit(.basebandConnected(.failure(.transport(-8))))
        await #expect(throws: BoseError.transport(-8)) { try await opening.value }
        #expect(link.openedChannelIDs.isEmpty)
    }

    @Test func channelRequestFailureFailsOpen() async {
        let link = FakeRFCOMMLink(isBasebandConnected: true)
        link.openChannelFailure = .transport(-9)
        let transport = makeTransport(link)
        await #expect(throws: BoseError.transport(-9)) { try await transport.open() }
        #expect(link.channel.closeRequests == 0)
    }

    @Test func channelOpenFailureFailsOpenAndClosesChannel() async {
        let link = FakeRFCOMMLink()
        let transport = makeTransport(link)
        let opening = Task { try await transport.open() }
        await link.waitUntil { $0.openedChannelIDs.count == 1 }
        link.emit(.channelOpened(.failure(.transport(-10))))
        await #expect(throws: BoseError.transport(-10)) { try await opening.value }
        #expect(link.channel.closeRequests == 1)
        link.emit(.channelClosed)
        await transport.close()
        #expect(link.channel.isDetached)
    }

    @Test func openTimesOut() async {
        let link = FakeRFCOMMLink(isBasebandConnected: false)
        let transport = makeTransport(link, timings: .patient.with(\.openDeadline, .milliseconds(50)))
        await #expect(throws: BoseError.timeout) { try await transport.open() }
        #expect(link.openedChannelIDs.isEmpty)
    }

    @Test func cancellationDuringOpenClosesRequestedChannel() async {
        let link = FakeRFCOMMLink()
        let transport = makeTransport(link)
        let opening = Task { try await transport.open() }
        await link.waitUntil { $0.openedChannelIDs.count == 1 }
        opening.cancel()
        await #expect(throws: CancellationError.self) { try await opening.value }
        await link.waitUntil { $0.channel.closeRequests == 1 }
        link.emit(.channelClosed)
        await transport.close()
        #expect(link.channel.isDetached)
    }

    @Test func secondOpenIsRejected() async throws {
        let link = FakeRFCOMMLink()
        let (transport, _) = try await openTransport(link)
        await #expect(throws: BoseError.disconnected) { try await transport.open() }
        #expect(link.connectRequests == 1)
    }

    @Test func openWhileConnectingIsRejected() async {
        let link = FakeRFCOMMLink(isBasebandConnected: false)
        let transport = makeTransport(link)
        let opening = Task { try await transport.open() }
        await link.waitUntil { $0.connectRequests == 1 }
        await #expect(throws: BoseError.disconnected) { try await transport.open() }
        opening.cancel()
        await #expect(throws: CancellationError.self) { try await opening.value }
    }

    @Test func deliversReceivedBytes() async throws {
        let link = FakeRFCOMMLink()
        let (transport, stream) = try await openTransport(link)
        var iterator = stream.makeAsyncIterator()
        link.emit(.received([1, 2, 3]))
        link.emit(.received([4]))
        #expect(try await iterator.next() == [1, 2, 3])
        #expect(try await iterator.next() == [4])
        link.channel.closeOutcome = .completed
        await transport.close()
        await #expect(throws: BoseError.disconnected) { for try await _ in stream {} }
    }

    @Test func chunksWritesByMTUInOrder() async throws {
        let link = FakeRFCOMMLink()
        let (transport, _) = try await openTransport(link)
        link.channel.maximumTransmissionUnit = 4
        let packet: [UInt8] = Array(0..<10)
        let writing = Task { try await transport.write(packet) }
        await link.waitUntil { $0.channel.writes.count == 1 }
        #expect(link.channel.writes.map(\.bytes) == [[0, 1, 2, 3]])
        link.completeWrite(0)
        await link.waitUntil { $0.channel.writes.count == 2 }
        #expect(link.channel.writes[1].bytes == [4, 5, 6, 7])
        link.completeWrite(1)
        await link.waitUntil { $0.channel.writes.count == 3 }
        #expect(link.channel.writes[2].bytes == [8, 9])
        link.completeWrite(2)
        try await writing.value
        #expect(Set(link.channel.writes.map(\.identifier)).count == 3)
    }

    @Test func oversizedWriteIsRejected() async throws {
        let link = FakeRFCOMMLink()
        let (transport, _) = try await openTransport(link)
        await #expect(throws: BoseError.invalidArgument("BMAP packet size")) {
            try await transport.write([UInt8](repeating: 0, count: BMAPPacket.maximumLength + 1))
        }
        #expect(link.channel.writes.isEmpty)
    }

    @Test func writeCompletionFailureTerminatesTransport() async throws {
        let link = FakeRFCOMMLink()
        let (transport, stream) = try await openTransport(link)
        let writing = Task { try await transport.write([1, 2]) }
        await link.waitUntil { $0.channel.writes.count == 1 }
        link.completeWrite(0, .failure(.transport(-11)))
        await #expect(throws: BoseError.transport(-11)) { try await writing.value }
        await #expect(throws: BoseError.transport(-11)) { for try await _ in stream {} }
        #expect(link.channel.closeRequests == 1)
        await #expect(throws: BoseError.disconnected) { try await transport.write([3]) }
    }

    @Test func writeSubmissionFailureTerminatesTransport() async throws {
        let link = FakeRFCOMMLink()
        let (transport, stream) = try await openTransport(link)
        link.channel.writeFailure = .transport(-12)
        await #expect(throws: BoseError.transport(-12)) { try await transport.write([1]) }
        await #expect(throws: BoseError.transport(-12)) { for try await _ in stream {} }
    }

    @Test func writeTimesOut() async throws {
        let link = FakeRFCOMMLink()
        let (transport, stream) = try await openTransport(
            link, timings: .patient.with(\.writeChunkDeadline, .milliseconds(50)))
        await #expect(throws: BoseError.timeout) { try await transport.write([1]) }
        await #expect(throws: BoseError.timeout) { for try await _ in stream {} }
        #expect(link.channel.closeRequests == 1)
    }

    @Test func cancelledWriteTerminatesTransport() async throws {
        let link = FakeRFCOMMLink()
        let (transport, stream) = try await openTransport(link)
        let writing = Task { try await transport.write([1]) }
        await link.waitUntil { $0.channel.writes.count == 1 }
        writing.cancel()
        await #expect(throws: CancellationError.self) { try await writing.value }
        await #expect(throws: CancellationError.self) { for try await _ in stream {} }
    }

    @Test func writeBeforeOpenThrowsDisconnected() async {
        let transport = makeTransport(FakeRFCOMMLink())
        await #expect(throws: BoseError.disconnected) { try await transport.write([1]) }
    }

    @Test func writeOnNativelyClosedChannelThrowsDisconnected() async throws {
        let link = FakeRFCOMMLink()
        let (transport, _) = try await openTransport(link)
        link.channel.isOpen = false
        await #expect(throws: BoseError.disconnected) { try await transport.write([1]) }
        #expect(link.channel.writes.isEmpty)
    }

    @Test func writeAfterCloseThrowsDisconnected() async throws {
        let link = FakeRFCOMMLink()
        let (transport, _) = try await openTransport(link)
        link.channel.closeOutcome = .completed
        await transport.close()
        await #expect(throws: BoseError.disconnected) { try await transport.write([1]) }
    }

    @Test func remoteCloseFailsStreamAndPendingWrite() async throws {
        let link = FakeRFCOMMLink()
        let (transport, stream) = try await openTransport(link)
        let writing = Task { try await transport.write([1]) }
        await link.waitUntil { $0.channel.writes.count == 1 }
        link.emit(.channelClosed)
        await #expect(throws: BoseError.disconnected) { try await writing.value }
        await #expect(throws: BoseError.disconnected) { for try await _ in stream {} }
        #expect(link.channel.isDetached)
        #expect(link.channel.closeRequests == 0)
        await transport.close()
    }

    @Test func closeWaitsForClosedNotificationThenSettlement() async throws {
        let settlement = Duration.milliseconds(100)
        let link = FakeRFCOMMLink()
        let (transport, stream) = try await openTransport(link, timings: .patient.with(\.closeSettlement, settlement))
        let closing = Task { await transport.close() }
        await link.waitUntil { $0.channel.closeRequests == 1 }
        #expect(!link.channel.isDetached)
        await #expect(throws: BoseError.disconnected) { for try await _ in stream {} }
        let clock = ContinuousClock()
        let notified = clock.now
        link.emit(.channelClosed)
        #expect(!link.channel.isDetached)
        await closing.value
        #expect(clock.now - notified >= settlement)
        #expect(link.channel.isDetached)
    }

    @Test func closeFallsBackWhenNotificationNeverArrives() async throws {
        let link = FakeRFCOMMLink()
        let (transport, _) = try await openTransport(link, timings: .patient.with(\.closeFallback, .milliseconds(50)))
        await transport.close()
        #expect(link.channel.closeRequests == 1)
        #expect(link.channel.isDetached)
    }

    @Test func closeFinishesImmediatelyWhenNativeCloseFails() async throws {
        let link = FakeRFCOMMLink()
        let (transport, _) = try await openTransport(link)
        link.channel.closeOutcome = .completed
        await transport.close()
        #expect(link.channel.isDetached)
    }

    @Test func closeBeforeOpenReturnsImmediatelyAndPreventsOpen() async {
        let link = FakeRFCOMMLink()
        let transport = makeTransport(link)
        await transport.close()
        await #expect(throws: BoseError.disconnected) { try await transport.open() }
        #expect(link.connectRequests == 0)
    }

    @Test func closeWhileAwaitingBasebandReturnsImmediately() async {
        let link = FakeRFCOMMLink(isBasebandConnected: false)
        let transport = makeTransport(link)
        let opening = Task { try await transport.open() }
        await link.waitUntil { $0.connectRequests == 1 }
        await transport.close()
        await #expect(throws: BoseError.disconnected) { try await opening.value }
        link.emit(.basebandConnected(.success(())))
        #expect(link.openedChannelIDs.isEmpty)
    }

    @Test func concurrentClosesShareOneTeardown() async throws {
        let link = FakeRFCOMMLink()
        let (transport, _) = try await openTransport(link)
        let first = Task { await transport.close() }
        let second = Task { await transport.close() }
        await link.waitUntil { $0.channel.closeRequests == 1 }
        link.emit(.channelClosed)
        await first.value
        await second.value
        await transport.close()
        #expect(link.channel.closeRequests == 1)
        #expect(link.channel.isDetached)
    }

    @Test func lateOpenCompletionAfterCloseClosesChannel() async {
        let link = FakeRFCOMMLink()
        let transport = makeTransport(link)
        let opening = Task { try await transport.open() }
        await link.waitUntil { $0.openedChannelIDs.count == 1 }
        let closing = Task { await transport.close() }
        await #expect(throws: BoseError.disconnected) { try await opening.value }
        await link.waitUntil { $0.channel.closeRequests == 1 }
        link.emit(.channelOpened(.success(())))
        #expect(link.channel.closeRequests == 2)
        link.emit(.channelClosed)
        await closing.value
        #expect(link.channel.isDetached)
    }
}

private extension RFCOMMTransportTimings {
    static let patient = RFCOMMTransportTimings(
        openDeadline: .seconds(30),
        writeChunkDeadline: .seconds(30),
        closeFallback: .seconds(30),
        closeSettlement: .zero
    )

    func with(_ keyPath: WritableKeyPath<RFCOMMTransportTimings, Duration>, _ value: Duration) -> RFCOMMTransportTimings {
        var timings = self
        timings[keyPath: keyPath] = value
        return timings
    }
}
