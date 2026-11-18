import Testing
@testable import BoseKitEngine

struct ProtocolTests {
    @Test(arguments: 0...8)
    func everySplitBoundary(_ split: Int) throws {
        let bytes: [UInt8] = [2, 2, 0x83, 1, 77, 1, 10, 3, 1, 7]
        var decoder = BMAPDecoder()
        let first = decoder.append(Array(bytes.prefix(split)))
        let second = decoder.append(Array(bytes.dropFirst(split)))
        #expect((first + second).map(\.payload) == [[77], [7]])
        #expect((first + second).first?.flags == 0x83)
        #expect(decoder.bufferedByteCount == 0)
    }

    @Test func incompleteTailSurvives() {
        var decoder = BMAPDecoder()
        #expect(decoder.append([2, 2, 3, 3, 1]).isEmpty)
        #expect(decoder.bufferedByteCount == 5)
        #expect(decoder.append([2, 3]).first?.payload == [1, 2, 3])
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
