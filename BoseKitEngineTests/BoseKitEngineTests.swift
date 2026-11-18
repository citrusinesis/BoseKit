import Foundation
import Testing
@testable import BoseKitEngine

private func profile(_ id: UInt16 = 0x4066) throws -> DeviceProfile {
    try #require(DeviceRegistry.standard().profile(productID: id))
}

actor ScriptedTransport: BMAPTransport {
    typealias Responder = @Sendable ([UInt8]) throws -> [[UInt8]]
    private let stream: AsyncThrowingStream<[UInt8], any Error>
    private let continuation: AsyncThrowingStream<[UInt8], any Error>.Continuation
    private let responder: Responder?
    private(set) var writes: [[UInt8]] = []
    private(set) var isClosed = false

    init(responder: Responder? = nil) {
        let pair = AsyncThrowingStream<[UInt8], any Error>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
        self.responder = responder
    }

    func open() -> AsyncThrowingStream<[UInt8], any Error> { stream }
    func write(_ bytes: [UInt8]) throws {
        guard !isClosed else { throw BoseError.disconnected }
        writes.append(bytes)
        if let responder {
            for chunk in try responder(bytes) { continuation.yield(chunk) }
        }
    }
    func inject(_ bytes: [UInt8]) { continuation.yield(bytes) }
    func close() { isClosed = true; continuation.finish() }
    func waitForWrites(_ count: Int) async throws {
        let clock = ContinuousClock()
        let end = clock.now.advanced(by: .seconds(2))
        while writes.count < count {
            guard clock.now < end else { throw BoseError.timeout }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
}

private func query(_ address: BMAPAddress = .init(2, 2), operation: BMAPOperator = .get,
                   timeout: Duration = .seconds(2)) throws -> BMAPCommand<[UInt8]> {
    BMAPCommand(packet: try BMAPPacket(address: address, operation: operation), timeout: timeout) {
        try #require($0.last).payload
    }
}

struct ProtocolTests {
    @Test(arguments: 0...8)
    func everySplitBoundary(_ split: Int) throws {
        let bytes: [UInt8] = [2, 2, 0x83, 1, 77, 1, 10, 3, 1, 7]
        var decoder = BMAPDecoder()
        let first = try decoder.append(Array(bytes.prefix(split)))
        let second = try decoder.append(Array(bytes.dropFirst(split)))
        #expect((first + second).map(\.payload) == [[77], [7]])
        #expect((first + second).first?.flags == 0x83)
        #expect(decoder.bufferedByteCount == 0)
    }

    @Test func incompleteTailSurvives() throws {
        var decoder = BMAPDecoder()
        #expect(try decoder.append([2, 2, 3, 3, 1]).isEmpty)
        #expect(decoder.bufferedByteCount == 5)
        #expect(try decoder.append([2, 3]).first?.payload == [1, 2, 3])
    }

    @Test func oversizedPayloadRejected() {
        #expect(throws: BoseError.self) {
            try BMAPPacket(address: .init(1, 2), operation: .setGet, payload: Array(repeating: 0, count: 256))
        }
    }

    @Test func unknownOperatorPreserved() throws {
        var decoder = BMAPDecoder()
        let packet = try #require(decoder.append([1, 2, 0xff, 0]).first)
        #expect(packet.operation == nil)
        #expect(packet.bytes == [1, 2, 0xff, 0])
    }
}

struct CodecTests {
    @Test func signedEQAndMalformedRecords() throws {
        let feature = BoseFeatures.equalizer
        let bands = try feature.decode([246, 10, 251, 0], profile())
        #expect(bands.first?.range == -10...10)
        #expect(bands.first?.value == -5)
        #expect(try feature.encode(EQAdjustment(band: 0, value: -5), profile()) == [251, 0])
        #expect(throws: BoseError.self) { try feature.decode([246, 10, 0], profile()) }
    }

    @Test func multipointUsesEnabledBit() throws {
        #expect(try BoseFeatures.multipoint.decode([7], profile()))
        #expect(try !BoseFeatures.multipoint.decode([6], profile()))
    }

    @Test func shortcutBitmapUsesBigEndian() throws {
        let value = try BoseFeatures.buttons.decode([0x80, 9, 19, 0, 9, 0x40, 0x0a], profile())
        #expect(Set(value.supportedActions.map(\.rawValue)) == [1, 3, 14, 16, 19])
        #expect(value.assignment.event == .longPress)
    }

    @Test func voicePromptsPreserveHighBits() throws {
        var value = try BoseFeatures.voicePrompts.decode([0xe1, 0, 0, 0, 0, 0, 1], profile())
        value.enabled = false
        #expect(try BoseFeatures.voicePrompts.encode(value, profile()) == [0xc1])
        value.enabled = true
        #expect(try BoseFeatures.voicePrompts.encode(value, profile()) == [0xe1])
    }

    @Test func componentBatteryFallback() throws {
        let value = try BoseFeatures.battery.decode([80, 0, 0, 1, 65, 0, 0, 2, 255, 0, 0, 4], profile(0x4062))
        #expect(value.percentage == 65)
        #expect(value.components == [.right: 80, .left: 65])
        #expect(throws: BoseError.self) {
            try BoseFeatures.battery.decode([80, 0, 0, 1, 70, 0, 0, 1], profile(0x4062))
        }
    }

    @Test func bluetoothAddressesParseBothSeparators() throws {
        let address = try #require(BluetoothAddress(string: "ac-bf-71-0a-1b-2c"))
        #expect(address.bytes == [0xac, 0xbf, 0x71, 0x0a, 0x1b, 0x2c])
        #expect(address.description == "AC:BF:71:0A:1B:2C")
        #expect(BluetoothAddress(string: "AC:BF:71:0A:1B") == nil)
        #expect(BluetoothAddress(string: "AC:BF:71:0A:1B:2") == nil)
        #expect(BluetoothAddress(string: "AC:BF:71:0A:1B:ZZ") == nil)
    }

    @Test func modeWriteHasExactOffsets() throws {
        let draft = ModeDraft(slot: 4, prompt: 0x000b, name: "Work",
                              audio: AudioSettings(cnc: 7, spatial: .motion, windBlock: true))
        let bytes = try StandardModeCodec(.status47).encodeWrite(draft)
        #expect(bytes.count == 39)
        #expect(Array(bytes.prefix(7)) == [4, 0, 11, 87, 111, 114, 107])
        #expect(Array(bytes[35...]) == [7, 0, 2, 1])
        #expect(bytes[34] == 0)
    }

    @Test func modeStatusIsNotWriteEcho() throws {
        let codec = StandardModeCodec(.status47)
        var bytes = [UInt8](repeating: 0, count: 47)
        bytes[0] = 4; bytes[2] = 11; bytes[3] = 1; bytes[4] = 1
        bytes[6] = 87; bytes[41] = 13; bytes[42] = 7; bytes[44] = 2; bytes[45] = 1
        let mode = try codec.decodeStatus(bytes)
        #expect(mode.audio?.cnc == 7)
        #expect(mode.audio?.spatial == .motion)
        #expect(mode.audio?.windBlock == false)
        #expect(throws: BoseError.self) { try codec.decodeStatus(Array(bytes.prefix(39))) }
    }

    @Test func unknown44ByteTailIsNotInvented() throws {
        let mode = try StandardModeCodec(.status44).decodeStatus(Array(repeating: 0, count: 44))
        #expect(mode.audio == nil)
    }

    @Test func rejectsUTF8OverflowAndNUL() throws {
        for name in [String(repeating: "한", count: 11), "bad\0name"] {
            #expect(throws: BoseError.self) {
                try StandardModeCodec(.status47).encodeWrite(ModeDraft(
                    slot: 4, prompt: 0, name: name, audio: AudioSettings(cnc: 0)))
            }
        }
    }

    @Test func registryIncludesAllUpstreamProductsAndLonestarr() throws {
        let registry = try DeviceRegistry.standard()
        for id: UInt16 in [0x400c, 0x4020, 0x4024, 0x4039, 0x4075, 0x4082, 0x4083, 0x402f, 0x4062, 0x4068, 0x4066] {
            #expect(registry.profile(productID: id) != nil)
        }
        #expect(registry.profile(productID: 0xffff) == nil)
        #expect(try profile(0x4020).rfcommChannel == 8)
        #expect(try profile(0x4024).initialization.first?.bytes == [9, 2, 2, 5, 1, 0, 5, 2, 0x37])
        #expect(try !profile(0x4024).supports(.equalizer, access: .write))
        #expect(try !profile().supports(.audioSettings))
        #expect(try profile().modePolicy?.deletionCNC == 10)
    }

    @Test func registrationRejectsAmbiguousProducts() throws {
        var registry = try DeviceRegistry.standard()
        #expect(throws: BoseError.self) { try registry.register(profile()) }
    }
}

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
        await Task.yield()
        #expect(await transport.writes.count == 1)
        await transport.inject([2, 2, 3, 1, 80])
        #expect(try await first.value == [80])
        try await transport.waitForWrites(2)
        await transport.inject([1, 10, 3, 1, 7])
        #expect(try await second.value == [7])
        await session.close()
    }

    @Test func timeoutClosesSessionAgainstLateReplies() async throws {
        let transport = ScriptedTransport()
        let session = try await BMAPSession.connect(transport: transport)
        await #expect(throws: BoseError.timeout) {
            try await session.execute(query(timeout: .milliseconds(20)))
        }
        #expect(await transport.isClosed)
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
        #expect(await transport.isClosed)
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

    @Test func collectionDrainsAndDeduplicatesAtFeatureLayer() async throws {
        let transport = ScriptedTransport(responder: { _ in
            [[31, 1, 7, 0], [31, 6, 3, 1, 0, 31, 6, 3, 1, 1], [31, 1, 6, 0]]
        })
        let session = try await BMAPSession.connect(transport: transport)
        let command = BMAPCommand(
            packet: try BMAPPacket(address: .init(31, 1), operation: .start),
            rule: ResponseRule(addresses: [.init(31, 6), .init(31, 1)], completion: .quiet(.milliseconds(10))),
            decode: { $0.filter { $0.address == .init(31, 6) }.map(\.payload) }
        )
        #expect(try await session.execute(command) == [[0], [1]])
        await session.close()
    }

    @Test func unsupportedWriteNeverReachesTransport() async throws {
        let transport = ScriptedTransport(responder: { bytes in [[bytes[0], bytes[1], 3, 0]] })
        let device = try await BoseDevice.connect(profile: profile(0x4024), transport: transport)
        await #expect(throws: BoseError.unsupported("equalizer")) {
            try await device.write(BoseFeatures.equalizer, value: EQAdjustment(band: 0, value: 1))
        }
        #expect(await transport.writes.count == 1)
        await device.close()
    }

    @Test func sourceDevicesUseCapturedLonestarrReplies() async throws {
        let list: [UInt8] = [0x03, 0x64, 0x31, 0x35, 0x81, 0x98, 0x67, 0xbc, 0xd0, 0x74, 0x72, 0x78, 0x52,
                             0x1c, 0xf6, 0x4c, 0x52, 0x34, 0xcb]
        let info: [[UInt8]: [UInt8]] = [
            [0x64, 0x31, 0x35, 0x81, 0x98, 0x67]: [0x01, 0x02, 0x03] + Array("lemon".utf8),
            [0xbc, 0xd0, 0x74, 0x72, 0x78, 0x52]: [0x03, 0x02, 0x03] + Array("juicer".utf8),
            [0x1c, 0xf6, 0x4c, 0x52, 0x34, 0xcb]: [0x00, 0x02, 0x03] + Array("mixer".utf8),
        ]
        let transport = ScriptedTransport(responder: { bytes in
            switch (bytes[0], bytes[1]) {
            case (4, 4): return [[4, 4, 3, UInt8(list.count)] + list]
            case (5, 1): return [[5, 1, 3, 9, 0x00, 0x0f, 0x01, 0x64, 0x31, 0x35, 0x81, 0x98, 0x67]]
            case (4, 5):
                let address = Array(bytes[4..<10])
                let payload = address + (info[address] ?? [])
                return [[4, 5, 3, UInt8(payload.count)] + payload]
            default: return [[bytes[0], bytes[1], 4, 1, 5]]
            }
        })
        let device = try await BoseDevice.connect(profile: profile(), transport: transport)
        let devices = try await device.sourceDevices()
        #expect(devices.map(\.name) == ["lemon", "juicer", "mixer"])
        #expect(devices.map(\.isConnected) == [true, true, false])
        #expect(devices.map(\.isRequestingHost) == [false, true, false])
        #expect(devices.map(\.isActiveSource) == [true, false, false])
        #expect(devices[1].address.description == "BC:D0:74:72:78:52")
        await device.close()
    }

    @Test func writeReturnsIndependentReadBack() async throws {
        let transport = ScriptedTransport(responder: { bytes in
            bytes[2] == 2 ? [[1, 10, 3, 1, 1]] : [[1, 10, 3, 1, 6]]
        })
        let device = try await BoseDevice.connect(profile: profile(), transport: transport)
        await #expect(throws: BoseError.verificationFailed("multipoint")) {
            try await device.write(BoseFeatures.multipoint, value: true, verify: { $0 == $1 })
        }
        #expect(await transport.writes.map { $0[2] } == [2, 1])
        await device.close()
    }
}
