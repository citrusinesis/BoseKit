import Testing
@testable import BoseKitEngine

@Suite(.timeLimit(.minutes(1)))
struct SessionLifecycleTests {
    @Test func responseBeforeWriteCompletionDoesNotOverlapNextWrite() async throws {
        let transport = ScriptedTransport(
            responder: { [frame(BMAPAddress($0[0], $0[1]), .status, [80])] },
            gatesWrites: true
        )
        let session = try await BMAPSession.connect(transport: transport)
        let first = Task { try await session.execute(query()) }
        let second = Task { try await session.execute(query()) }
        try await transport.waitForWrites(1)
        await transport.completeWrite()
        try await transport.waitForWrites(2)
        await transport.completeWrite()
        #expect(try await first.value == [80])
        #expect(try await second.value == [80])
        #expect(await transport.peakConcurrentWrites == 1)
        await session.close()
    }

    @Test func queuedCancellationLeavesActiveRequestUsable() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let first = Task { try await session.execute(query()) }
        try await transport.waitForWrites(1)
        let second = Task { try await session.execute(query()) }
        second.cancel()
        await #expect(throws: CancellationError.self) { try await second.value }
        await transport.inject([2, 2, 3, 1, 80])
        #expect(try await first.value == [80])
        #expect(await !transport.isClosed)
        #expect(await transport.writes.count == 1)
        await session.close()
    }

    @Test func disconnectReleasesPendingRequest() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let request = Task { try await session.execute(query()) }
        try await transport.waitForWrites(1)
        await transport.close()
        await #expect(throws: BoseError.disconnected) { try await request.value }
    }

    @Test func timeoutClosesSessionAgainstLateReplies() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        await #expect(throws: BoseError.timeout) {
            try await session.execute(query(timeout: .milliseconds(100)))
        }
        try await transport.waitUntilClosed()
        await transport.inject([2, 2, 3, 1, 100])
        await #expect(throws: BoseError.disconnected) { try await session.execute(query()) }
    }

    @Test func cancellationClosesActiveRequest() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let request = Task { try await session.execute(query()) }
        try await transport.waitForWrites(1)
        request.cancel()
        await #expect(throws: CancellationError.self) { try await request.value }
        try await transport.waitUntilClosed()
    }

    @Test func requestsAfterCloseAreRejected() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        await session.close()
        await #expect(throws: BoseError.disconnected) { try await session.execute(query()) }
        #expect(await transport.writes.isEmpty)
    }

    @Test func eventsStreamFinishesWhenSessionCloses() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let events = await session.events()
        await session.close()
        var iterator = events.makeAsyncIterator()
        #expect(await iterator.next() == nil)
    }
}
