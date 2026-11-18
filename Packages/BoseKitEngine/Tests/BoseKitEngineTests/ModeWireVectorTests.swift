import Testing
@testable import BoseKitEngine

private func modeStatus(
    head: [UInt8], name: [UInt8], unknown: [UInt8], tail: [UInt8]
) -> [UInt8] {
    head + padded(name, to: 32) + unknown + tail
}

struct ModeStatusVectorTests {
    private struct Vector: Sendable, CustomTestStringConvertible {
        let name: String
        let layout: StandardModeCodec.Layout
        let payload: [UInt8]
        let expected: ModeConfiguration

        init(_ name: String, _ layout: StandardModeCodec.Layout, _ payload: [UInt8], _ expected: ModeConfiguration) {
            self.name = name
            self.layout = layout
            self.payload = payload
            self.expected = expected
        }

        var testDescription: String { name }
    }

    private static let unknownMarkers: [UInt8] = [0xe1, 0xe2, 0xe3, 0xe4]

    private static let vectors: [Vector] = {
        let first47 = modeStatus(head: [0x07, 0x01, 0x2c, 0x02, 0x00, 0x03], name: Array("Café".utf8),
                             unknown: unknownMarkers, tail: [9, 5, 2, 0xe5, 0])
        let second47 = modeStatus(head: [0x05, 0x00, 0x0b, 0x00, 0x01, 0x00], name: Array("Work".utf8),
                              unknown: unknownMarkers, tail: [4, 0, 1, 0xe5, 9])
        let first48 = modeStatus(head: [0x07, 0x01, 0x2c, 0x02, 0x00, 0x03], name: Array("Café".utf8),
                             unknown: unknownMarkers, tail: [9, 5, 2, 0xe5, 0, 7])
        let second48 = modeStatus(head: [0x05, 0x00, 0x0b, 0x00, 0x01, 0x00], name: Array("Work".utf8),
                              unknown: unknownMarkers, tail: [4, 0, 1, 0xe5, 9, 0])
        let first44 = modeStatus(head: [0x07, 0x01, 0x2c, 0x02, 0x00, 0x03], name: Array("Café".utf8),
                             unknown: unknownMarkers, tail: [0xaa, 0xbb])
        let second44 = modeStatus(head: [0x05, 0x00, 0x0b, 0x00, 0x01, 0x00], name: Array("Work".utf8),
                              unknown: unknownMarkers, tail: [0xff, 0xff])
        let fullField = modeStatus(head: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
                               name: Array(repeating: 0x71, count: 32), unknown: unknownMarkers, tail: [0, 0, 0, 0, 0])
        let junkAfterNUL = modeStatus(head: [0x01, 0x00, 0x00, 0x00, 0x00, 0x00],
                                  name: Array("Ab".utf8) + [0x00] + Array("junk".utf8),
                                  unknown: unknownMarkers, tail: [0, 0, 0, 0, 0])
        let emptyName = modeStatus(head: [0x02, 0x00, 0x00, 0x00, 0x00, 0x00], name: [], unknown: unknownMarkers,
                               tail: [0, 0, 0, 0, 0])
        let unknownPrompt = modeStatus(head: [0x03, 0x12, 0x34, 0x00, 0x00, 0x00], name: Array("X".utf8),
                                   unknown: unknownMarkers, tail: [0, 0, 0, 0, 0])
        let maxPrompt = modeStatus(head: [0xff, 0xff, 0xff, 0x01, 0x01, 0x01], name: [], unknown: unknownMarkers,
                               tail: [10, 0, 0, 0, 0])

        return [
            Vector("47 byte status with editable favorite and every audio field set", .status47, first47,
                   ModeConfiguration(
                       id: 7, prompt: ModePrompt(rawValue: 300), name: "Café", editable: true, configured: false,
                       favorite: true,
                       audio: AudioSettings(cnc: 9, automaticCNC: true, spatial: .motion, windBlock: false, ancEnabled: nil),
                       rawPayload: first47)),
            Vector("47 byte status with configured mode and wind block", .status47, second47,
                   ModeConfiguration(
                       id: 5, prompt: .work, name: "Work", editable: false, configured: true, favorite: false,
                       audio: AudioSettings(cnc: 4, automaticCNC: false, spatial: .still, windBlock: true, ancEnabled: nil),
                       rawPayload: second47)),
            Vector("48 byte status adds ANC state in the last byte", .status48, first48,
                   ModeConfiguration(
                       id: 7, prompt: ModePrompt(rawValue: 300), name: "Café", editable: true, configured: false,
                       favorite: true,
                       audio: AudioSettings(cnc: 9, automaticCNC: true, spatial: .motion, windBlock: false, ancEnabled: true),
                       rawPayload: first48)),
            Vector("48 byte status with ANC off and wind block on", .status48, second48,
                   ModeConfiguration(
                       id: 5, prompt: .work, name: "Work", editable: false, configured: true, favorite: false,
                       audio: AudioSettings(cnc: 4, automaticCNC: false, spatial: .still, windBlock: true, ancEnabled: false),
                       rawPayload: second48)),
            Vector("44 byte status has no audio settings", .status44, first44,
                   ModeConfiguration(
                       id: 7, prompt: ModePrompt(rawValue: 300), name: "Café", editable: true, configured: false,
                       favorite: true, audio: nil, rawPayload: first44)),
            Vector("44 byte status ignores out of range tail bytes", .status44, second44,
                   ModeConfiguration(
                       id: 5, prompt: .work, name: "Work", editable: false, configured: true, favorite: false,
                       audio: nil, rawPayload: second44)),
            Vector("name field of 32 non NUL bytes decodes in full", .status47, fullField,
                   ModeConfiguration(
                       id: 0, prompt: .none, name: String(repeating: "q", count: 32), editable: false,
                       configured: false, favorite: false,
                       audio: AudioSettings(cnc: 0, automaticCNC: false, spatial: .off, windBlock: false, ancEnabled: nil),
                       rawPayload: fullField)),
            Vector("name stops at the first NUL even with bytes after it", .status47, junkAfterNUL,
                   ModeConfiguration(
                       id: 1, prompt: .none, name: "Ab", editable: false, configured: false, favorite: false,
                       audio: AudioSettings(cnc: 0, automaticCNC: false, spatial: .off, windBlock: false, ancEnabled: nil),
                       rawPayload: junkAfterNUL)),
            Vector("all NUL name field is the empty string", .status47, emptyName,
                   ModeConfiguration(
                       id: 2, prompt: .none, name: "", editable: false, configured: false, favorite: false,
                       audio: AudioSettings(cnc: 0, automaticCNC: false, spatial: .off, windBlock: false, ancEnabled: nil),
                       rawPayload: emptyName)),
            Vector("unknown prompt value is kept open", .status47, unknownPrompt,
                   ModeConfiguration(
                       id: 3, prompt: ModePrompt(rawValue: 0x1234), name: "X", editable: false, configured: false,
                       favorite: false,
                       audio: AudioSettings(cnc: 0, automaticCNC: false, spatial: .off, windBlock: false, ancEnabled: nil),
                       rawPayload: unknownPrompt)),
            Vector("prompt 0xffff and slot 0xff with maximum cnc", .status47, maxPrompt,
                   ModeConfiguration(
                       id: 0xff, prompt: ModePrompt(rawValue: 0xffff), name: "", editable: true, configured: true,
                       favorite: true,
                       audio: AudioSettings(cnc: 10, automaticCNC: false, spatial: .off, windBlock: false, ancEnabled: nil),
                       rawPayload: maxPrompt)),
        ]
    }()

    @Test(arguments: vectors)
    private func decodes(_ vector: Vector) throws {
        #expect(try StandardModeCodec(vector.layout).decodeStatus(vector.payload) == vector.expected)
    }

    @Test func unknownPromptHasNoProtocolName() throws {
        let vector = try #require(Self.vectors.first { $0.name.hasPrefix("unknown prompt") })
        let mode = try StandardModeCodec(vector.layout).decodeStatus(vector.payload)
        #expect(mode.prompt.protocolName == nil)
    }

    @Test(arguments: [(StandardModeCodec.Layout.status44, 44), (.status47, 47), (.status48, 48)])
    func statusLengthMatchesTheLayout(_ layout: StandardModeCodec.Layout, _ length: Int) {
        #expect(StandardModeCodec(layout).statusLength == length)
    }
}

struct ModeStatusRejectionVectorTests {
    private static func valid(_ layout: StandardModeCodec.Layout) -> [UInt8] {
        let tail: [UInt8] = switch layout {
        case .status44: [0, 0]
        case .status47: [3, 0, 0, 0, 0]
        case .status48: [3, 0, 0, 0, 0, 0]
        }
        return modeStatus(head: [4, 0, 0, 1, 1, 0], name: Array("Work".utf8), unknown: zeros(4), tail: tail)
    }

    private static let layouts: [StandardModeCodec.Layout] = [.status44, .status47, .status48]

    @Test(arguments: layouts)
    func statusOneByteShortIsRejected(_ layout: StandardModeCodec.Layout) {
        let payload = Array(Self.valid(layout).dropLast())
        expectInvalidPayload { try StandardModeCodec(layout).decodeStatus(payload) }
    }

    @Test(arguments: layouts)
    func statusWithOneTrailingByteIsRejected(_ layout: StandardModeCodec.Layout) {
        let payload = Self.valid(layout) + [0]
        expectInvalidPayload { try StandardModeCodec(layout).decodeStatus(payload) }
    }

    @Test(arguments: layouts)
    func statusOfAnotherLayoutLengthIsRejected(_ layout: StandardModeCodec.Layout) {
        for other in Self.layouts where other != layout {
            let payload = Self.valid(other)
            expectInvalidPayload { try StandardModeCodec(layout).decodeStatus(payload) }
        }
    }

    @Test func emptyStatusIsRejected() {
        expectInvalidPayload { try StandardModeCodec(.status47).decodeStatus([]) }
    }

    @Test func invalidUTF8NameIsRejected() {
        var payload = Self.valid(.status47)
        payload[6] = 0xff
        expectInvalidPayload { try StandardModeCodec(.status47).decodeStatus(payload) }
    }

    @Test(arguments: [StandardModeCodec.Layout.status47, .status48])
    func cncAboveMaximumIsRejected(_ layout: StandardModeCodec.Layout) {
        var payload = Self.valid(layout)
        payload[42] = 11
        expectInvalidPayload { try StandardModeCodec(layout).decodeStatus(payload) }
    }

    @Test(arguments: [StandardModeCodec.Layout.status47, .status48])
    func unknownSpatialValueIsRejected(_ layout: StandardModeCodec.Layout) {
        var payload = Self.valid(layout)
        payload[44] = 3
        expectInvalidPayload { try StandardModeCodec(layout).decodeStatus(payload) }
    }

    @Test func status44IgnoresAudioBytesThatWouldBeInvalidElsewhere() throws {
        var payload = Self.valid(.status44)
        payload[42] = 0xff
        payload[44 - 1] = 0xff
        #expect(try StandardModeCodec(.status44).decodeStatus(payload).audio == nil)
    }
}

struct ModeWriteVectorTests {
    private struct Vector: Sendable, CustomTestStringConvertible {
        let name: String
        let layout: StandardModeCodec.Layout
        let draft: ModeDraft
        let expected: [UInt8]

        init(_ name: String, _ layout: StandardModeCodec.Layout, _ draft: ModeDraft, _ expected: [UInt8]) {
            self.name = name
            self.layout = layout
            self.draft = draft
            self.expected = expected
        }

        var testDescription: String { name }
    }

    private static let vectors: [Vector] = [
        Vector("47 byte layout with every field set", .status47,
               ModeDraft(slot: 4, prompt: ModePrompt(rawValue: 300), name: "Café",
                         audio: AudioSettings(cnc: 9, automaticCNC: true, spatial: .motion, windBlock: true)),
               [4, 0x01, 0x2c] + padded(Array("Café".utf8), to: 32) + [9, 1, 2, 1]),
        Vector("47 byte layout with everything off and empty name", .status47,
               ModeDraft(slot: 3, prompt: .none, name: "", audio: AudioSettings(cnc: 0)),
               [3, 0, 0] + zeros(32) + [0, 0, 0, 0]),
        Vector("47 byte layout with spatial still and maximum cnc", .status47,
               ModeDraft(slot: 9, prompt: .work, name: "Work", audio: AudioSettings(cnc: 10, spatial: .still)),
               [9, 0, 11] + padded(Array("Work".utf8), to: 32) + [10, 0, 1, 0]),
        Vector("47 byte layout with a thirty one byte name", .status47,
               ModeDraft(slot: 5, prompt: ModePrompt(rawValue: 0xffff),
                         name: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn", audio: AudioSettings(cnc: 1)),
               [5, 0xff, 0xff] + Array(repeating: 0x6e, count: 31) + [0] + [1, 0, 0, 0]),
        Vector("48 byte layout appends ANC on", .status48,
               ModeDraft(slot: 4, prompt: ModePrompt(rawValue: 300), name: "Café",
                         audio: AudioSettings(cnc: 9, automaticCNC: true, spatial: .motion, windBlock: true,
                                              ancEnabled: true)),
               [4, 0x01, 0x2c] + padded(Array("Café".utf8), to: 32) + [9, 1, 2, 1, 1]),
        Vector("48 byte layout appends ANC off", .status48,
               ModeDraft(slot: 6, prompt: .music, name: "Music",
                         audio: AudioSettings(cnc: 2, spatial: .still, ancEnabled: false)),
               [6, 0, 12] + padded(Array("Music".utf8), to: 32) + [2, 0, 1, 0, 0]),
    ]

    @Test(arguments: vectors)
    private func encodes(_ vector: Vector) throws {
        #expect(try StandardModeCodec(vector.layout).encodeWrite(vector.draft) == vector.expected)
    }

    @Test func thirtyTwoByteNameCannotBeConstructedAndThirtyOneIsWritten() throws {
        let name = try #require(ModeName(rawValue: String(repeating: "n", count: 31)))
        _ = try StandardModeCodec(.status47).encodeWrite(ModeDraft(slot: 3, prompt: .none, name: name,
                                                                   audio: AudioSettings(cnc: 0)))
        #expect(ModeName(rawValue: String(repeating: "n", count: 32)) == nil)
    }

    @Test func writePayloadIsThirtyNineBytesFor47AndFortyFor48() throws {
        let draft = ModeDraft(slot: 3, prompt: .none, name: "a", audio: AudioSettings(cnc: 0, ancEnabled: false))
        let draft47 = ModeDraft(slot: 3, prompt: .none, name: "a", audio: AudioSettings(cnc: 0))
        #expect(try StandardModeCodec(.status47).encodeWrite(draft47).count == 39)
        #expect(try StandardModeCodec(.status48).encodeWrite(draft).count == 40)
    }

    @Test func writeIsNotTheStatusLayoutForTheSameFields() throws {
        let statusBytes = modeStatus(head: [4, 0, 11, 1, 1, 0], name: Array("Work".utf8), unknown: zeros(4), tail: [7, 0, 2, 0, 1])
        let mode = try StandardModeCodec(.status47).decodeStatus(statusBytes)
        let draft = ModeDraft(slot: mode.id, prompt: mode.prompt, name: try #require(ModeName(rawValue: mode.name)),
                              audio: try #require(mode.audio))
        let written = try StandardModeCodec(.status47).encodeWrite(draft)
        #expect(written != statusBytes)
        #expect(written.count == statusBytes.count - 8)
    }
}
