import Foundation
import Testing
@testable import BoseKitEngine

private actor EarlyReplyTransport: BMAPTransport {
    private let stream: AsyncThrowingStream<[UInt8], any Error>
    private let sink: AsyncThrowingStream<[UInt8], any Error>.Continuation
    private var writing = false
    private(set) var overlappingWrites = false

    init() {
        let pair = AsyncThrowingStream<[UInt8], any Error>.makeStream()
        stream = pair.stream
        sink = pair.continuation
    }

    func open() -> AsyncThrowingStream<[UInt8], any Error> { stream }
    func close() { sink.finish() }
    func write(_ bytes: [UInt8]) async throws {
        if writing { overlappingWrites = true }
        writing = true
        sink.yield([bytes[0], bytes[1], 3, 1, 80])
        try await Task.sleep(for: .milliseconds(30))
        writing = false
    }
}

struct SessionLifecycleTests {
    private func command() throws -> BMAPCommand<[UInt8]> {
        BMAPCommand(packet: try BMAPPacket(address: .init(2, 2), operation: .get)) {
            try #require($0.last).payload
        }
    }

    @Test func responseBeforeWriteCompletionDoesNotOverlapNextWrite() async throws {
        let transport = EarlyReplyTransport()
        let session = try await BMAPSession.connect(transport: transport)
        async let first = session.execute(command())
        async let second = session.execute(command())
        _ = try await (first, second)
        #expect(await !transport.overlappingWrites)
        await session.close()
    }

    @Test func queuedCancellationLeavesActiveRequestUsable() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        let first = Task { try await session.execute(command()) }
        try await transport.waitForWrites(1)
        let second = Task { try await session.execute(command()) }
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
        let request = Task { try await session.execute(command()) }
        try await transport.waitForWrites(1)
        await transport.close()
        await #expect(throws: BoseError.disconnected) { try await request.value }
    }

    @Test func vendorIDSourcePreventsFalseProductMatches() {
        #expect(BluetoothProductIdentity(vendorIDSource: 1, vendorID: 0x009e, productID: 0x4066).isBose)
        #expect(BluetoothProductIdentity(vendorIDSource: 2, vendorID: 0x05a7, productID: 0x4082).isBose)
        #expect(!BluetoothProductIdentity(vendorIDSource: 2, vendorID: 0x009e, productID: 0x4066).isBose)
    }
}
