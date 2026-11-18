import Testing
@testable import BoseKitEngine

struct WireLeniencyTests {
    private static let phone: [UInt8] = [0x64, 0x31, 0x35, 0x81, 0x98, 0x67]

    private static let vectors: [TrailingByteVector] = [
        .init("battery percentage", BoseFeatures.battery, minimumLength: 1, valid: [55], end: .trailingBytesAllowed),
        .init("cnc", BoseFeatures.cnc, minimumLength: 3, valid: [11, 7, 1], end: .trailingBytesAllowed),
        .init("anr", BoseFeatures.anr, minimumLength: 1, valid: [2], end: .trailingBytesAllowed),
        .init("multipoint", BoseFeatures.multipoint, minimumLength: 1, valid: [1], end: .trailingBytesAllowed),
        .init("auto pause", BoseFeatures.autoPause, minimumLength: 1, valid: [1], end: .trailingBytesAllowed),
        .init("auto answer", BoseFeatures.autoAnswer, minimumLength: 1, valid: [1], end: .trailingBytesAllowed),
        .init("pairing", BoseFeatures.pairing, minimumLength: 1, valid: [1], end: .trailingBytesAllowed),
        .init("sidetone", BoseFeatures.sidetone, minimumLength: 2, valid: [1, 2], end: .trailingBytesAllowed),
        .init("favorites", BoseFeatures.favorites, minimumLength: 3, valid: [4, 0, 0b0101], end: .trailingBytesAllowed),
        .init("default mode", BoseFeatures.defaultMode, minimumLength: 1, valid: [3], end: .trailingBytesAllowed),
        .init("audio settings", BoseFeatures.audioSettings, minimumLength: 5, valid: [7, 1, 2, 1, 1],
              end: .trailingBytesAllowed),
        .init("source other than bluetooth", BoseFeatures.source, minimumLength: 3, valid: [0, 0x0f, 2],
              end: .trailingBytesAllowed),
        .init("voice prompts", BoseFeatures.voicePrompts, minimumLength: 1, valid: [0xa1], end: .trailingBytesAllowed),
        .init("buttons with full bitmap", BoseFeatures.buttons, minimumLength: 7, valid: [0x80, 9, 19, 0, 9, 0x40, 0x0a],
              end: .trailingBytesAllowed),
        .init("source bluetooth", BoseFeatures.source, minimumLength: 9, valid: [0, 0x0f, 1] + phone, end: .exact),
        .init("name", BoseFeatures.name, minimumLength: 1, valid: [0], end: .exact),
    ]

    private static let tolerant = vectors.filter { $0.end == .trailingBytesAllowed }

    @Test(arguments: tolerant)
    func decodeIgnoresTrailingBytesWhereThePolicyAllowsThem(_ vector: TrailingByteVector) throws {
        #expect(vector.valid.count == vector.minimumLength)
        #expect(try vector.decodesEqually(vector.valid, vector.valid + [0xaa]))
        #expect(try vector.decodesEqually(vector.valid, vector.valid + [0xaa, 0xbb, 0xcc, 0xdd, 0xee]))
    }

    @Test(arguments: vectors)
    func payloadOneByteShortOfTheMinimumIsRejected(_ vector: TrailingByteVector) {
        #expect(vector.valid.count == vector.minimumLength)
        let short = Array(vector.valid.dropLast())
        expectInvalidPayload { try vector.decodesEqually(short, short) }
    }

    @Test func sourceBluetoothRejectsTrailingBytes() throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.source.decode([0, 0x0f, 1] + Self.phone + [0xaa], resolved) }
    }

    @Test(arguments: [[0xaa], [0xaa, 0xbb], [0xaa, 0xbb, 0xcc]] as [[UInt8]])
    func buttonsRejectAPartialBitmap(_ bitmap: [UInt8]) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.buttons.decode([0x80, 9, 19] + bitmap, resolved) }
    }

    @Test func voicePromptsIgnoreTrailingBytes() throws {
        let value = try BoseFeatures.voicePrompts.decode([0xa1, 0xaa, 0xbb], wireProfile())
        #expect(value == VoicePrompts(enabled: true, language: .englishUS, preservedBits: 0x80))
    }

    @Test func nameTrailingBytesBecomePartOfTheName() throws {
        #expect(try BoseFeatures.name.decode([0, 0x41, 0x42], wireProfile()) == "AB")
    }

    @Test func percentageBatteryLayoutReadsOnlyTheFirstByte() throws {
        let value = try BoseFeatures.battery.decode([80, 0, 0, 1, 65, 0, 0, 2], wireProfile())
        #expect(value == BatteryStatus(percentage: 80, components: [:]))
    }

    @Test func componentBatteryLayoutRejectsAnyPayloadThatIsNotWholeRecords() throws {
        let edith = try wireProfile(0x4062)
        for length in [1, 2, 3, 5, 6, 7, 9] {
            expectInvalidPayload { try BoseFeatures.battery.decode(Array(repeating: 50, count: length), edith) }
        }
    }

    @Test func equalizerRejectsAnyPayloadThatIsNotWholeRecords() throws {
        for length in [1, 2, 3, 5, 6, 7, 9] {
            let payload = Array(repeating: UInt8(0), count: length)
            expectInvalidPayload { try BoseFeatures.equalizer.decode(payload, wireProfile()) }
        }
    }
}
