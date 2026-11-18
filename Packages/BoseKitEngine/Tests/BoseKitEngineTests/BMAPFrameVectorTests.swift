import Testing
@testable import BoseKitEngine

struct BMAPFrameVectorTests {
    private struct PacketVector: Sendable, CustomTestStringConvertible {
        let name: String
        let address: BMAPAddress
        let flags: UInt8
        let payload: [UInt8]
        let bytes: [UInt8]
        let operation: BMAPOperator?

        init(_ name: String, _ block: UInt8, _ function: UInt8, flags: UInt8, _ payload: [UInt8],
             bytes: [UInt8], operation: BMAPOperator?) {
            self.name = name
            address = BMAPAddress(block, function)
            self.flags = flags
            self.payload = payload
            self.bytes = bytes
            self.operation = operation
        }

        var testDescription: String { name }
    }

    private static let packets: [PacketVector] = [
        .init("zero length payload", 4, 4, flags: 0x01, [], bytes: [4, 4, 0x01, 0], operation: .get),
        .init("single byte payload", 2, 2, flags: 0x03, [80], bytes: [2, 2, 0x03, 1, 80], operation: .status),
        .init("upper flag bits are preserved", 5, 6, flags: 0x83, [1], bytes: [5, 6, 0x83, 1, 1], operation: .status),
        .init("all upper flag bits set", 5, 6, flags: 0xf2, [9, 8], bytes: [5, 6, 0xf2, 2, 9, 8], operation: .setGet),
        .init("operator nibble 8 is unknown", 1, 2, flags: 0x08, [], bytes: [1, 2, 0x08, 0], operation: nil),
        .init("operator nibble 15 is unknown", 1, 2, flags: 0xff, [], bytes: [1, 2, 0xff, 0], operation: nil),
        .init("address 0xff 0xff", 0xff, 0xff, flags: 0x00, [0xff], bytes: [0xff, 0xff, 0x00, 1, 0xff], operation: .set),
    ]

    @Test(arguments: packets)
    private func packetEncodesAndReportsItsOperation(_ vector: PacketVector) throws {
        let packet = try BMAPPacket(address: vector.address, flags: vector.flags, payload: vector.payload)
        #expect(packet.bytes == vector.bytes)
        #expect(packet.operation == vector.operation)
    }

    @Test(arguments: zip(
        [BMAPOperator.set, .get, .setGet, .status, .error, .start, .result, .processing],
        [UInt8(0), 1, 2, 3, 4, 5, 6, 7]
    ))
    func operatorRawValuesAreTheLowNibble(_ operation: BMAPOperator, _ raw: UInt8) throws {
        #expect(operation.rawValue == raw)
        let packet = try BMAPPacket(address: BMAPAddress(1, 2), operation: operation)
        #expect(packet.bytes == [1, 2, raw, 0])
        #expect(packet.flags == raw)
    }

    @Test func maximumLengthPayloadEncodesAndRoundTrips() throws {
        let payload = (0..<255).map { UInt8($0) }
        let packet = try BMAPPacket(address: BMAPAddress(31, 6), flags: 0x42, payload: payload)
        #expect(packet.bytes.count == 259)
        #expect(Array(packet.bytes.prefix(4)) == [31, 6, 0x42, 255])
        #expect(Array(packet.bytes.dropFirst(4)) == payload)
        var decoder = BMAPDecoder()
        #expect(decoder.append(packet.bytes) == [packet])
        #expect(decoder.bufferedByteCount == 0)
    }

    @Test func payloadOneByteOverTheMaximumIsRejected() {
        expectInvalidArgument {
            try BMAPPacket(address: BMAPAddress(1, 2), flags: 0, payload: Array(repeating: 0, count: 256))
        }
    }

    @Test func zeroLengthFrameDecodesFromExactlyTheHeader() throws {
        var decoder = BMAPDecoder()
        let packets = decoder.append([31, 3, 0x86, 0])
        #expect(packets == [try BMAPPacket(address: BMAPAddress(31, 3), flags: 0x86, payload: [])])
        #expect(decoder.bufferedByteCount == 0)
    }

    @Test func severalFramesInOneChunkDecodeInOrder() throws {
        let long = Array(repeating: UInt8(0xab), count: 255)
        let chunk: [UInt8] = [2, 2, 0x03, 1, 77] + [1, 10, 0x83, 0] + [31, 6, 0x03, 255] + long + [4, 5, 0x06, 2, 9, 8]
        var decoder = BMAPDecoder()
        let packets = decoder.append(chunk)
        #expect(packets == [
            try BMAPPacket(address: BMAPAddress(2, 2), flags: 0x03, payload: [77]),
            try BMAPPacket(address: BMAPAddress(1, 10), flags: 0x83, payload: []),
            try BMAPPacket(address: BMAPAddress(31, 6), flags: 0x03, payload: long),
            try BMAPPacket(address: BMAPAddress(4, 5), flags: 0x06, payload: [9, 8]),
        ])
        #expect(decoder.bufferedByteCount == 0)
    }

    @Test func completeFramesAreEmittedWhileATrailingPartialFrameIsKept() throws {
        var decoder = BMAPDecoder()
        let packets = decoder.append([2, 2, 0x03, 1, 77, 1, 10, 0x03])
        #expect(packets.map(\.payload) == [[77]])
        #expect(decoder.bufferedByteCount == 3)
        #expect(decoder.append([2, 7, 7]).map(\.payload) == [[7, 7]])
        #expect(decoder.bufferedByteCount == 0)
    }

    @Test func maximumLengthFrameFedOneByteAtATimeDecodesOnlyOnTheLastByte() throws {
        let payload = (0..<255).map { UInt8($0) }
        let bytes = try BMAPPacket(address: BMAPAddress(31, 6), flags: 0x03, payload: payload).bytes
        var decoder = BMAPDecoder()
        var decoded: [BMAPPacket] = []
        for byte in bytes.dropLast() {
            decoded += decoder.append([byte])
        }
        #expect(decoded.isEmpty)
        #expect(decoder.bufferedByteCount == 258)
        decoded += decoder.append([bytes[bytes.count - 1]])
        #expect(decoded.map(\.payload) == [payload])
        #expect(decoder.bufferedByteCount == 0)
    }

    @Test func emptyChunkProducesNothing() {
        var decoder = BMAPDecoder()
        #expect(decoder.append([]).isEmpty)
        #expect(decoder.bufferedByteCount == 0)
    }
}
