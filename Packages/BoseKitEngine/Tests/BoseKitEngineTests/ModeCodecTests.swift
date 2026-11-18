import Testing
@testable import BoseKitEngine

struct ModeCodecTests {
    @Test func modeWriteHasExactOffsets() throws {
        let draft = ModeDraft(slot: 4, prompt: .work, name: "Work",
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

    @Test func modeNameRejectsUTF8OverflowAndNUL() {
        for name in [String(repeating: "한", count: 11), "bad\0name"] {
            #expect(ModeName(rawValue: name) == nil)
        }
    }

    @Test func status44LayoutRejectsWrites() {
        let draft = ModeDraft(slot: 4, prompt: .none, name: "Work", audio: AudioSettings(cnc: 0))
        #expect(throws: BoseError.unsupported(.modeWritesInStatus44Layout)) {
            try StandardModeCodec(.status44).encodeWrite(draft)
        }
    }

    @Test func status48LayoutWritesANCStateAndRequiresIt() throws {
        let codec = StandardModeCodec(.status48)
        let withANC = ModeDraft(slot: 4, prompt: .none, name: "Work", audio: AudioSettings(cnc: 0, ancEnabled: true))
        #expect(try codec.encodeWrite(withANC).last == 1)
        let withoutANC = ModeDraft(slot: 4, prompt: .none, name: "Work", audio: AudioSettings(cnc: 0))
        #expect(throws: BoseError.self) { try codec.encodeWrite(withoutANC) }
    }

    @Test func status47LayoutRejectsANCState() {
        let draft = ModeDraft(slot: 4, prompt: .none, name: "Work", audio: AudioSettings(cnc: 0, ancEnabled: true))
        #expect(throws: BoseError.unsupported(.ancToggleInStatus47Layout)) {
            try StandardModeCodec(.status47).encodeWrite(draft)
        }
    }
}
