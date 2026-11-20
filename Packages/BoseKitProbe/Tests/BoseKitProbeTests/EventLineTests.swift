import BoseKitEngine
import Testing
@testable import BoseKitProbe

struct EventLineTests {
    private func event(_ bytes: [UInt8], _ origin: BMAPEvent.Origin) throws -> BMAPEvent {
        var decoder = BMAPDecoder()
        return BMAPEvent(packet: try #require(decoder.append(bytes).first), origin: origin)
    }

    @Test func unsolicitedStatusShowsAddressNameOperatorAndPayload() throws {
        let line = EventLine.format(try event([31, 3, 3, 2, 0x03, 0xa0], .unsolicited), time: "12:00:00.000")
        #expect(line == "12:00:00.000  unsolicited  [31.3]  current mode       STATUS      03 a0")
    }

    @Test func replyWithEmptyPayloadKeepsItsColumns() throws {
        let line = EventLine.format(try event([1, 5, 7, 0], .reply), time: "12:00:00.000")
        #expect(line == "12:00:00.000  reply        [1.5]   cnc                PROCESSING  ")
    }

    @Test func unknownAddressHasNoNameButKeepsTheOperatorColumnAligned() throws {
        let unknown = EventLine.format(try event([2, 99, 3, 1, 0x01], .unsolicited), time: "t")
        let known = EventLine.format(try event([2, 2, 3, 1, 0x01], .unsolicited), time: "t")
        #expect(unknown.contains("[2.99]  "))
        #expect(try #require(unknown.firstRange(of: "STATUS")).lowerBound.utf16Offset(in: unknown)
            == (try #require(known.firstRange(of: "STATUS")).lowerBound.utf16Offset(in: known)))
    }

    @Test func unknownOperatorShowsTheRawFlags() throws {
        let line = EventLine.format(try event([2, 2, 0xff, 0], .unsolicited), time: "t")
        #expect(line.contains("FLAGS ff"))
    }

    @Test func errorPacketsNameKnownCodesAndLeaveUnknownOnesAsBytes() throws {
        let known = EventLine.format(try event([4, 12, 4, 1, 0x04], .reply), time: "t")
        let unknown = EventLine.format(try event([4, 12, 4, 1, 0x42], .reply), time: "t")
        #expect(known.hasSuffix("04 (FuncNotSupp)"))
        #expect(unknown.hasSuffix("42"))
        #expect(EventLine.errorPayload([]) == "")
    }
}
