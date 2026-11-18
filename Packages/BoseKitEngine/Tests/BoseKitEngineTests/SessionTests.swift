import Testing
@testable import BoseKitEngine

@Suite(.timeLimit(.minutes(1)))
struct SessionTests {
    @Test func processingDoesNotCompleteStart() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let request = Task { try await session.execute(query(.init(31, 3), operation: .start)) }
        try await transport.waitForWrites(1)
        await transport.inject([31, 3, 7, 0, 31, 3, 3, 1, 9])
        await transport.inject([31, 3, 6, 1, 2])
        #expect(try await request.value == [2])
        await session.close()
    }

    @Test func unrelatedStatusIsPublishedAndDoesNotCompleteRequest() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let events = await session.events()
        let event = Task { var iterator = events.makeAsyncIterator(); return await iterator.next() }
        let request = Task { try await session.execute(query()) }
        try await transport.waitForWrites(1)
        await transport.inject([31, 3, 3, 1, 2, 2, 2, 3, 1, 90])
        #expect(try await request.value == [90])
        #expect(await event.value?.address == BMAPAddress(31, 3))
        await session.close()
    }

    @Test func concurrentRequestsAreSerialized() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let first = Task { try await session.execute(query()) }
        try await transport.waitForWrites(1)
        let second = Task { try await session.execute(query(.init(1, 10))) }
        await transport.inject(frame(.init(2, 2), .status, [80]))
        #expect(try await first.value == [80])
        try await transport.waitForWrites(2)
        await transport.inject(frame(.init(1, 10), .status, [7]))
        #expect(try await second.value == [7])
        #expect(await transport.log == [
            .wrote(frame(.init(2, 2), .get)),
            .delivered(frame(.init(2, 2), .status, [80])),
            .wrote(frame(.init(1, 10), .get)),
            .delivered(frame(.init(1, 10), .status, [7])),
        ])
        await session.close()
    }

    @Test func remoteErrorDoesNotCorruptNextRequest() async throws {
        let transport = ScriptedTransport(responder: { bytes in
            bytes[0] == 1 ? [[1, 5, 4, 1, 5]] : [[2, 2, 3, 1, 75]]
        })
        let session = try await BMAPSession.connect(transport: transport)
        await #expect(throws: BoseError.device(.init(1, 5), code: 5)) {
            try await session.execute(query(.init(1, 5)))
        }
        #expect(try await session.execute(query()) == [75])
        await session.close()
    }

    @Test func remoteErrorWithoutPayloadHasNoCode() async throws {
        let transport = ScriptedTransport(responder: { _ in [[1, 5, 4, 0]] })
        let session = try await BMAPSession.connect(transport: transport)
        await #expect(throws: BoseError.device(.init(1, 5), code: nil)) {
            try await session.execute(query(.init(1, 5)))
        }
        await session.close()
    }

    @Test func quietCompletionCollectsStatusAndResultRepliesFromEveryRuleAddress() async throws {
        let transport = ScriptedTransport(responder: { _ in
            [[31, 1, 7, 0] + [31, 6, 3, 1, 0, 31, 6, 3, 1, 1] + [31, 1, 6, 0]]
        })
        let session = try await BMAPSession.connect(transport: transport)
        let command = BMAPCommand(
            packet: try BMAPPacket(address: .init(31, 1), operation: .start),
            rule: ResponseRule(addresses: [.init(31, 6), .init(31, 1)], completion: .quiet(.milliseconds(50))),
            decode: { packets in packets.map { [$0.address.function, $0.payload.first ?? 0xff] } }
        )
        #expect(try await session.execute(command) == [[6, 0], [6, 1], [1, 0xff]])
        await session.close()
    }

    @Test func isCompleteEndsQuietCollectionWithoutWaitingForTheWindow() async throws {
        let transport = ScriptedTransport(responder: { _ in [[31, 6, 3, 1, 0, 31, 6, 3, 1, 1]] })
        let session = try await BMAPSession.connect(transport: transport)
        let command = BMAPCommand(
            packet: try BMAPPacket(address: .init(31, 1), operation: .start),
            rule: ResponseRule(
                addresses: [.init(31, 6)],
                completion: .quiet(.seconds(60)),
                isComplete: { $0.count == 2 }
            ),
            decode: { $0.map(\.payload) }
        )
        #expect(try await session.execute(command) == [[0], [1]])
        await session.close()
    }
}
