import Testing
@testable import BoseKitEngine

struct CNCLevelTests {
    @Test(arguments: [UInt8(0), 5, 10])
    func levelsInRangeAreAccepted(_ raw: UInt8) throws {
        #expect(try #require(CNCLevel(rawValue: raw)).rawValue == raw)
    }

    @Test(arguments: [UInt8(11), 255])
    func levelsAboveTheMaximumAreRejected(_ raw: UInt8) {
        #expect(CNCLevel(rawValue: raw) == nil)
    }

    @Test func boundsMatchTheRange() {
        #expect(CNCLevel.minimum.rawValue == 0)
        #expect(CNCLevel.maximum.rawValue == 10)
        #expect(CNCLevel.minimum < CNCLevel.maximum)
    }

    @Test func decodingOutsideTheRangeIsAnInvalidPayload() {
        expectInvalidPayload { try CNCLevel(decoding: 11) }
    }
}

struct RFCOMMChannelTests {
    @Test(arguments: [UInt8(1), 2, 30])
    func channelsInRangeAreAccepted(_ raw: UInt8) throws {
        #expect(try #require(RFCOMMChannel(rawValue: raw)).rawValue == raw)
    }

    @Test(arguments: [UInt8(0), 31, 255])
    func channelsOutsideTheRangeAreRejected(_ raw: UInt8) {
        #expect(RFCOMMChannel(rawValue: raw) == nil)
    }
}

struct NameTests {
    @Test(arguments: ["a", "Citrus QC", String(repeating: "z", count: 31), String(repeating: "한", count: 10)])
    func namesWithinThirtyOneBytesAreAccepted(_ value: String) throws {
        #expect(try #require(DeviceName(rawValue: value)).rawValue == value)
        #expect(try #require(ModeName(rawValue: value)).rawValue == value)
    }

    @Test(arguments: [String(repeating: "z", count: 32), String(repeating: "한", count: 11), "bad\0name", "\0"])
    func overlongOrNULNamesAreRejected(_ value: String) {
        #expect(DeviceName(rawValue: value) == nil)
        #expect(ModeName(rawValue: value) == nil)
    }

    @Test func onlyModeNamesMayBeEmpty() {
        #expect(DeviceName(rawValue: "") == nil)
        #expect(ModeName(rawValue: "")?.rawValue == "")
    }
}

struct FavoriteModesTypeTests {
    @Test func slotsBelowTheCountAreAccepted() throws {
        let value = try FavoriteModes(slotCount: 16, slots: [0, 15])
        #expect(value.slots == [0, 15])
    }
}

struct VoicePromptsTypeTests {
    @Test func flagsRoundTripThroughTheFields() {
        for flags in UInt8.min...UInt8.max {
            let value = VoicePrompts(flags: flags)
            #expect(value.flags == flags)
        }
    }

    @Test func preservedBitsKeepOnlyTheTopTwoBits() {
        let value = VoicePrompts(enabled: false, language: .englishUK, preservedBits: 0xff)
        #expect(value.preservedBits == 0xc0)
        #expect(value.flags == 0xc0)
    }
}

struct EQAdjustmentTests {
    private static let band = EQBand(id: 2, range: -6...6, value: 0)

    @Test(arguments: [Int8(-6), 0, 6])
    func valuesInsideTheBandRangeAreAccepted(_ value: Int8) throws {
        let adjustment = try Self.band.adjustment(to: value)
        #expect(adjustment.band == 2)
        #expect(adjustment.value == value)
    }

    @Test(arguments: [Int8(-7), 7, .min, .max])
    func valuesOutsideTheBandRangeAreRejected(_ value: Int8) {
        expectInvalidArgument { try Self.band.adjustment(to: value) }
    }
}

struct PayloadReaderTests {
    @Test func readsFieldsSequentiallyInBigEndian() throws {
        let fields = try PayloadReader.parse([1, 0x12, 0x34, 0xde, 0xad, 0xbe, 0xef, 0], end: .exact) { reader in
            (try reader.u8(), try reader.u16(), try reader.u32(), try reader.bool())
        }
        #expect(fields.0 == 1)
        #expect(fields.1 == 0x1234)
        #expect(fields.2 == 0xdeadbeef)
        #expect(fields.3 == false)
    }

    @Test func underrunIsAnInvalidPayload() {
        expectInvalidPayload { try PayloadReader.parse([1], end: .trailingBytesAllowed) { try $0.u16() } }
    }

    @Test func exactEndRejectsTrailingBytesAndTolerantEndIgnoresThem() throws {
        expectInvalidPayload { try PayloadReader.parse([1, 2], end: .exact) { try $0.u8() } }
        #expect(try PayloadReader.parse([1, 2], end: .trailingBytesAllowed) { try $0.u8() } == 1)
    }

    @Test func nulTerminatedFieldStopsAtTheFirstNUL() throws {
        let name = try PayloadReader.parse(Array("Ab".utf8) + [0, 0x7a, 0], end: .exact) {
            try $0.nulTerminatedString(fieldLength: 5)
        }
        #expect(name == "Ab")
    }

    @Test func remainingTextStripsTrailingNULsAndRejectsEmbeddedOnes() throws {
        #expect(try PayloadReader.parse([0x41, 0, 0], end: .exact) { try $0.remainingString(.ascii) } == "A")
        expectInvalidPayload { try PayloadReader.parse([0x41, 0, 0x42], end: .exact) { try $0.remainingString(.utf8) } }
        expectInvalidPayload { try PayloadReader.parse([0xc3, 0xa9], end: .exact) { try $0.remainingString(.ascii) } }
    }
}
