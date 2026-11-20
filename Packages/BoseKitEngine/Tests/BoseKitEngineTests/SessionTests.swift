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

    @Test func unrelatedStatusIsPublishedAsUnsolicitedAndDoesNotCompleteRequest() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let events = await session.events()
        let received = Task {
            var iterator = events.makeAsyncIterator()
            return [await iterator.next(), await iterator.next()]
        }
        let request = Task { try await session.execute(query()) }
        try await transport.waitForWrites(1)
        await transport.inject(frame(.currentMode, .status, [2]) + frame(.battery, .status, [90]))
        #expect(try await request.value == [90])
        let published = await received.value
        #expect(published.map { $0?.packet.address } == [.currentMode, .battery])
        #expect(published.map { $0?.origin } == [.unsolicited, .reply])
        await session.close()
    }

    @Test func packetsArrivingWithNoRequestInFlightAreUnsolicited() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let events = await session.events()
        await transport.inject(frame(.battery, .status, [55]))
        var iterator = events.makeAsyncIterator()
        let event = await iterator.next()
        #expect(event?.origin == .unsolicited)
        #expect(event?.packet.payload == [55])
        await session.close()
    }

    @Test func processingAndErrorPacketsForTheRequestAddressAreReplies() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let events = await session.events()
        let received = Task {
            var iterator = events.makeAsyncIterator()
            return [await iterator.next(), await iterator.next()]
        }
        let request = Task { try await session.execute(query(.currentMode, operation: .start)) }
        try await transport.waitForWrites(1)
        await transport.inject(frame(.currentMode, .processing) + frame(.currentMode, .error, [4]))
        await #expect(throws: BoseError.device(.currentMode, code: .functionNotSupported, detail: nil)) { try await request.value }
        #expect(await received.value.map { $0?.origin } == [.reply, .reply])
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
        await #expect(throws: BoseError.device(.init(1, 5), code: .operatorNotSupported, detail: nil)) {
            try await session.execute(query(.init(1, 5)))
        }
        #expect(try await session.execute(query()) == [75])
        await session.close()
    }

    @Test func remoteErrorWithoutPayloadHasNoCode() async throws {
        let transport = ScriptedTransport(responder: { _ in [[1, 5, 4, 0]] })
        let session = try await BMAPSession.connect(transport: transport)
        await #expect(throws: BoseError.device(.init(1, 5), code: nil, detail: nil)) {
            try await session.execute(query(.init(1, 5)))
        }
        await session.close()
    }

    @Test func remoteErrorPreservesAnUnknownCode() async throws {
        let transport = ScriptedTransport(responder: { _ in [frame(.init(1, 5), .error, [0x42, 9])] })
        let session = try await BMAPSession.connect(transport: transport)
        await #expect(throws: BoseError.device(.init(1, 5), code: BMAPErrorCode(rawValue: 0x42), detail: nil)) {
            try await session.execute(query(.init(1, 5)))
        }
        await session.close()
    }

    @Test func functionBlockSpecificErrorKeepsTheFollowingByte() async throws {
        let transport = ScriptedTransport(responder: { _ in [frame(.init(1, 5), .error, [0xFF, 0x21])] })
        let session = try await BMAPSession.connect(transport: transport)
        await #expect(throws: BoseError.device(.init(1, 5), code: .functionBlockSpecific, detail: 0x21)) {
            try await session.execute(query(.init(1, 5)))
        }
        await session.close()
    }

    @Test func functionBlockSpecificErrorWithoutTheFollowingByteHasNoDetail() async throws {
        let transport = ScriptedTransport(responder: { _ in [frame(.init(1, 5), .error, [0xFF])] })
        let session = try await BMAPSession.connect(transport: transport)
        await #expect(throws: BoseError.device(.init(1, 5), code: .functionBlockSpecific, detail: nil)) {
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
