import Testing
@testable import BoseKitEngine

private let lonestarr: UInt16 = 0x4066
private let edith: UInt16 = 0x4062

struct BatteryDecodeVectorTests {
    private static let percentage: [DecodeVector<BatteryStatus>] = [
        .init("percentage 0", [0], BatteryStatus(percentage: 0, components: [:])),
        .init("percentage 57", [57], BatteryStatus(percentage: 57, components: [:])),
        .init("percentage 100 is kept", [100], BatteryStatus(percentage: 100, components: [:])),
        .init("percentage 101 is dropped", [101], BatteryStatus(percentage: nil, components: [:])),
        .init("percentage 255 is dropped", [255], BatteryStatus(percentage: nil, components: [:])),
    ]

    private static let components: [DecodeVector<BatteryStatus>] = [
        .init("overall aggregate wins over right and left", product: edith,
              [80, 0, 0, 1, 65, 0, 0, 2, 72, 0, 0, 4],
              BatteryStatus(percentage: 72, components: [.right: 80, .left: 65, .overall: 72])),
        .init("record order does not matter", product: edith,
              [72, 0, 0, 4, 65, 0, 0, 2, 80, 0, 0, 1],
              BatteryStatus(percentage: 72, components: [.right: 80, .left: 65, .overall: 72])),
        .init("middle record bytes are ignored", product: edith,
              [80, 0xaa, 0xbb, 1, 65, 0xcc, 0xdd, 2, 72, 0xee, 0xff, 4],
              BatteryStatus(percentage: 72, components: [.right: 80, .left: 65, .overall: 72])),
        .init("fallback is the minimum when right is higher", product: edith,
              [80, 0, 0, 1, 65, 0, 0, 2],
              BatteryStatus(percentage: 65, components: [.right: 80, .left: 65])),
        .init("fallback is the minimum when left is higher", product: edith,
              [60, 0, 0, 1, 65, 0, 0, 2],
              BatteryStatus(percentage: 60, components: [.right: 60, .left: 65])),
        .init("fallback with only right present", product: edith,
              [80, 0, 0, 1], BatteryStatus(percentage: 80, components: [.right: 80])),
        .init("fallback with only left present", product: edith,
              [44, 0, 0, 2], BatteryStatus(percentage: 44, components: [.left: 44])),
        .init("overall only", product: edith,
              [90, 0, 0, 4], BatteryStatus(percentage: 90, components: [.overall: 90])),
        .init("overall 100 is kept", product: edith,
              [100, 0, 0, 4], BatteryStatus(percentage: 100, components: [.overall: 100])),
        .init("overall above 100 is dropped and fallback applies", product: edith,
              [255, 0, 0, 4, 80, 0, 0, 1, 65, 0, 0, 2],
              BatteryStatus(percentage: 65, components: [.right: 80, .left: 65])),
        .init("right above 100 is dropped from the fallback", product: edith,
              [101, 0, 0, 1, 65, 0, 0, 2],
              BatteryStatus(percentage: 65, components: [.left: 65])),
        .init("every value above 100 leaves no percentage", product: edith,
              [200, 0, 0, 1, 150, 0, 0, 4],
              BatteryStatus(percentage: nil, components: [:])),
        .init("charging case alone gives no percentage", product: edith,
              [90, 0, 0, 3],
              BatteryStatus(percentage: nil, components: [.chargingCase: 90])),
        .init("charging case does not enter the fallback minimum", product: edith,
              [20, 0, 0, 3, 80, 0, 0, 1, 65, 0, 0, 2],
              BatteryStatus(percentage: 65, components: [.chargingCase: 20, .right: 80, .left: 65])),
        .init("unknown component is retained verbatim", product: edith,
              [50, 0, 0, 9],
              BatteryStatus(percentage: nil, components: [BatteryComponent(rawValue: 9): 50])),
    ]

    private static let rejected: [RejectedPayload] = [
        .init("empty payload with percentage layout", []),
        .init("empty payload with component layout", product: edith, []),
        .init("three bytes with component layout", product: edith, [80, 0, 0]),
        .init("five bytes with component layout", product: edith, [80, 0, 0, 1, 65]),
        .init("single byte percentage with component layout", product: edith, [80]),
        .init("duplicate component", product: edith, [80, 0, 0, 1, 70, 0, 0, 1]),
        .init("duplicate component is detected before the value filter", product: edith,
              [101, 0, 0, 1, 70, 0, 0, 1]),
    ]

    @Test(arguments: percentage)
    func percentageLayoutDecodes(_ vector: DecodeVector<BatteryStatus>) throws {
        #expect(try BoseFeatures.battery.decode(vector.payload, wireProfile(vector.product)) == vector.expected)
    }

    @Test(arguments: components)
    func componentLayoutDecodes(_ vector: DecodeVector<BatteryStatus>) throws {
        #expect(try BoseFeatures.battery.decode(vector.payload, wireProfile(vector.product)) == vector.expected)
    }

    @Test(arguments: rejected)
    func malformedPayloadsAreRejected(_ vector: RejectedPayload) throws {
        let resolved = try wireProfile(vector.product)
        expectInvalidPayload { try BoseFeatures.battery.decode(vector.payload, resolved) }
    }
}

struct TextFeatureDecodeVectorTests {
    private static let nameVectors: [DecodeVector<String>] = [
        .init("ascii name after the leading byte", [0x00] + Array("Citrus QC".utf8), "Citrus QC"),
        .init("leading byte is not a length", [0x0b] + Array("Hi".utf8), "Hi"),
        .init("leading byte 0xff is dropped", [0xff] + Array("Hi".utf8), "Hi"),
        .init("empty name", [0x00], ""),
        .init("multibyte name", [0x00] + Array("한글 🎧".utf8), "한글 🎧"),
        .init("trailing NUL padding is stripped", [0x00, 0x41, 0x42, 0x00, 0x00], "AB"),
        .init("all NUL text is the empty name", [0x00, 0x00, 0x00], ""),
        .init("thirty one byte name", [0x00] + Array(repeating: 0x7a, count: 31), String(repeating: "z", count: 31)),
    ]

    private static let readOnlyVectors: [DecodeVector<String>] = [
        .init("firmware string", Array("1.6.7+g6ebabd2".utf8), "1.6.7+g6ebabd2"),
        .init("serial digits", Array("084322F1234567AE".utf8), "084322F1234567AE"),
        .init("empty text", [], ""),
        .init("trailing NUL is stripped", [0x31, 0x2e, 0x30, 0x00], "1.0"),
    ]

    @Test(arguments: nameVectors)
    func nameDecodes(_ vector: DecodeVector<String>) throws {
        #expect(try BoseFeatures.name.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test func nameRejectsEmptyPayloadAndInvalidUTF8() throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.name.decode([], resolved) }
        expectInvalidPayload { try BoseFeatures.name.decode([0x00, 0xff, 0xfe], resolved) }
    }

    @Test func nameRejectsAnEmbeddedNUL() throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.name.decode([0x00, 0x41, 0x00, 0x42], resolved) }
        expectInvalidPayload { try BoseFeatures.name.decode([0x00, 0x41, 0x00, 0x42, 0x00], resolved) }
    }

    @Test(arguments: readOnlyVectors)
    func readOnlyTextDecodesWithTrailingNULsStripped(_ vector: DecodeVector<String>) throws {
        let resolved = try wireProfile()
        #expect(try BoseFeatures.firmware.decode(vector.payload, resolved) == vector.expected)
        #expect(try BoseFeatures.serial.decode(vector.payload, resolved) == vector.expected)
        #expect(try BoseFeatures.model.decode(vector.payload, resolved) == vector.expected)
    }

    @Test func readOnlyTextRejectsNonASCII() throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.firmware.decode([0x31, 0xc3, 0xa9], resolved) }
        expectInvalidPayload { try BoseFeatures.serial.decode([0x80], resolved) }
        expectInvalidPayload { try BoseFeatures.model.decode([0xff], resolved) }
    }

    @Test func readOnlyTextRejectsAnEmbeddedNUL() throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.firmware.decode([0x31, 0x00, 0x30], resolved) }
        expectInvalidPayload { try BoseFeatures.serial.decode([0x00, 0x31, 0x00], resolved) }
        expectInvalidPayload { try BoseFeatures.model.decode([0x41, 0x00, 0x42, 0x00], resolved) }
    }
}

struct NoiseControlDecodeVectorTests {
    private static let cnc: [DecodeVector<CNCStatus>] = [
        .init("level 7 of 11 steps", [11, 7, 1], CNCStatus(current: 7, maximum: 10)),
        .init("level 0 of 11 steps", [11, 0, 1], CNCStatus(current: 0, maximum: 10)),
        .init("top level", [11, 10, 0], CNCStatus(current: 10, maximum: 10)),
        .init("single step", [1, 0, 0], CNCStatus(current: 0, maximum: 0)),
        .init("widest range", [255, 254, 0], CNCStatus(current: 254, maximum: 254)),
        .init("third byte is ignored", [11, 7, 0xaa], CNCStatus(current: 7, maximum: 10)),
    ]

    private static let rejectedCNC: [RejectedPayload] = [
        .init("empty", []),
        .init("two bytes", [11, 7]),
        .init("zero step count", [0, 0, 0]),
        .init("zero step count with current zero and flag", [0, 0, 1]),
        .init("current equals step count", [5, 5, 0]),
        .init("current above step count", [5, 9, 0]),
    ]

    private static let anr: [DecodeVector<ANRLevel>] = [
        .init("off", [0], .off),
        .init("high", [1], .high),
        .init("wind", [2], .wind),
        .init("low", [3], .low),
        .init("second byte is ignored", [2, 9], .wind),
    ]

    private static let sidetone: [DecodeVector<SidetoneLevel>] = [
        .init("off", [1, 0], .off),
        .init("high", [1, 1], .high),
        .init("medium", [1, 2], .medium),
        .init("low", [1, 3], .low),
        .init("first byte is ignored", [0xaa, 2], .medium),
    ]

    @Test(arguments: cnc)
    func cncDecodes(_ vector: DecodeVector<CNCStatus>) throws {
        #expect(try BoseFeatures.cnc.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: rejectedCNC)
    func cncRejectsInvalidRanges(_ vector: RejectedPayload) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.cnc.decode(vector.payload, resolved) }
    }

    @Test(arguments: anr)
    func anrDecodes(_ vector: DecodeVector<ANRLevel>) throws {
        #expect(try BoseFeatures.anr.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: [[], [4], [0xff]] as [[UInt8]])
    func anrRejectsUnknownRawValues(_ payload: [UInt8]) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.anr.decode(payload, resolved) }
    }

    @Test(arguments: sidetone)
    func sidetoneDecodes(_ vector: DecodeVector<SidetoneLevel>) throws {
        #expect(try BoseFeatures.sidetone.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: [[], [1], [1, 4], [1, 0xff]] as [[UInt8]])
    func sidetoneRejectsShortPayloadsAndUnknownRawValues(_ payload: [UInt8]) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.sidetone.decode(payload, resolved) }
    }
}

struct EqualizerDecodeVectorTests {
    private static let vectors: [DecodeVector<[EQBand]>] = [
        .init("single band with negative value", [246, 10, 251, 0],
              [EQBand(id: 0, range: -10...10, value: -5)]),
        .init("three bands with distinct ranges and signs", [244, 12, 250, 0, 246, 10, 0, 1, 250, 6, 6, 2],
              [EQBand(id: 0, range: -12...12, value: -6),
               EQBand(id: 1, range: -10...10, value: 0),
               EQBand(id: 2, range: -6...6, value: 6)]),
        .init("band ids keep wire order and need not be sequential", [246, 10, 1, 7, 246, 10, 255, 3],
              [EQBand(id: 7, range: -10...10, value: 1),
               EQBand(id: 3, range: -10...10, value: -1)]),
        .init("most negative value", [128, 127, 128, 0], [EQBand(id: 0, range: -128...127, value: -128)]),
        .init("most positive value", [128, 127, 127, 9], [EQBand(id: 9, range: -128...127, value: 127)]),
        .init("collapsed range", [0, 0, 0, 4], [EQBand(id: 4, range: 0...0, value: 0)]),
    ]

    private static let rejected: [RejectedPayload] = [
        .init("empty", []),
        .init("three bytes", [246, 10, 0]),
        .init("five bytes", [246, 10, 0, 0, 1]),
        .init("minimum above maximum", [10, 246, 0, 0]),
        .init("value above maximum", [246, 10, 11, 0]),
        .init("value below minimum", [246, 10, 245, 0]),
        .init("duplicate band id", [246, 10, 0, 2, 246, 10, 1, 2]),
    ]

    @Test(arguments: vectors)
    func decodes(_ vector: DecodeVector<[EQBand]>) throws {
        #expect(try BoseFeatures.equalizer.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: rejected)
    func rejectsMalformedRecords(_ vector: RejectedPayload) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.equalizer.decode(vector.payload, resolved) }
    }
}

struct ToggleDecodeVectorTests {
    private static let multipoint: [DecodeVector<Bool>] = [
        .init("0x00", [0x00], false),
        .init("0x01", [0x01], true),
        .init("0x02 sets only bit 1", [0x02], false),
        .init("0x03", [0x03], true),
        .init("0x06", [0x06], false),
        .init("0x07", [0x07], true),
        .init("0x80", [0x80], false),
        .init("0xfe", [0xfe], false),
        .init("0xff", [0xff], true),
    ]

    private static let fullMask: [DecodeVector<Bool>] = [
        .init("0x00", [0x00], false),
        .init("0x01", [0x01], true),
        .init("0x02", [0x02], true),
        .init("0x80", [0x80], true),
        .init("0xff", [0xff], true),
    ]

    private static let fullMaskFeatures: [BoseFeature<Bool, Bool>] = [
        BoseFeatures.autoPause, BoseFeatures.autoAnswer, BoseFeatures.pairing,
    ]

    @Test(arguments: multipoint)
    func multipointReadsBitZeroOnly(_ vector: DecodeVector<Bool>) throws {
        #expect(try BoseFeatures.multipoint.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: fullMask)
    func otherTogglesTreatAnyNonZeroByteAsOn(_ vector: DecodeVector<Bool>) throws {
        let resolved = try wireProfile()
        for feature in Self.fullMaskFeatures {
            #expect(try feature.decode(vector.payload, resolved) == vector.expected, "\(feature.id.rawValue)")
        }
    }

    @Test func everyToggleRejectsEmptyPayload() throws {
        let resolved = try wireProfile()
        for feature in Self.fullMaskFeatures + [BoseFeatures.multipoint] {
            expectInvalidPayload { try feature.decode([], resolved) }
        }
    }
}

struct VoicePromptsDecodeVectorTests {
    private static let vectors: [DecodeVector<VoicePrompts>] = [
        .init("all clear", [0x00],
              VoicePrompts(enabled: false, language: .englishUK, preservedBits: 0x00)),
        .init("enabled bit alone", [0x20],
              VoicePrompts(enabled: true, language: .englishUK, preservedBits: 0x00)),
        .init("language alone", [0x01],
              VoicePrompts(enabled: false, language: .englishUS, preservedBits: 0x00)),
        .init("enabled with language", [0x29],
              VoicePrompts(enabled: true, language: .korean, preservedBits: 0x00)),
        .init("language field is the low five bits", [0x1f],
              VoicePrompts(enabled: false, language: VoicePromptLanguage(bits: 31), preservedBits: 0x00)),
        .init("unknown language is kept open", [0x3f],
              VoicePrompts(enabled: true, language: VoicePromptLanguage(bits: 31), preservedBits: 0x00)),
        .init("bit 4 belongs to the language", [0x50],
              VoicePrompts(enabled: false, language: .cantonese, preservedBits: 0x40)),
        .init("high bits do not leak into language or enabled", [0xc0],
              VoicePrompts(enabled: false, language: .englishUK, preservedBits: 0xc0)),
        .init("high bits with enabled and language", [0xe1],
              VoicePrompts(enabled: true, language: .englishUS, preservedBits: 0xc0)),
        .init("QC Ultra 1st Gen reports its eight installed languages", [0xe1, 0x00, 0x01, 0x81, 0x5e, 0x01, 0x00],
              VoicePrompts(enabled: true, language: .englishUS, preservedBits: 0xc0, installedLanguages: [
                  .englishUS, .french, .italian, .german, .spanish, .mandarin, .japanese, .cantonese,
              ])),
        .init("QC Ultra 2nd Gen capture reports three installed languages", [0x41, 0x00, 0x00, 0x81, 0x02, 0x00, 0x00],
              VoicePrompts(enabled: false, language: .englishUS, preservedBits: 0x40,
                           installedLanguages: [.englishUS, .mandarin, .japanese])),
        .init("empty bitmap means no language is reported as installed", [0xe1, 0, 0, 0, 0],
              VoicePrompts(enabled: true, language: .englishUS, preservedBits: 0xc0, installedLanguages: [])),
        .init("fewer than four bytes after the flags are not a bitmap", [0xe1, 0xff, 0xff, 0xff],
              VoicePrompts(enabled: true, language: .englishUS, preservedBits: 0xc0)),
    ]

    @Test(arguments: vectors)
    func decodes(_ vector: DecodeVector<VoicePrompts>) throws {
        #expect(try BoseFeatures.voicePrompts.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test func rejectsEmptyPayload() throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.voicePrompts.decode([], resolved) }
    }
}

struct ButtonsDecodeVectorTests {
    private static func configuration(
        button: UInt8, event: UInt8, action: UInt8, supported: Set<UInt8>
    ) -> ButtonConfiguration {
        ButtonConfiguration(
            assignment: ButtonAssignment(button: button, event: ButtonEvent(rawValue: event),
                                         action: ButtonAction(rawValue: action)),
            supportedActions: Set(supported.map { ButtonAction(rawValue: $0) })
        )
    }

    private static let vectors: [DecodeVector<ButtonConfiguration>] = [
        .init("captured shortcut layout", [0x80, 9, 19, 0, 9, 0x40, 0x0a],
              configuration(button: 0x80, event: 9, action: 19, supported: [1, 3, 14, 16, 19])),
        .init("bytes are assignment then big-endian bitmap", [0x81, 9, 17, 0x00, 0x20, 0x00, 0x04],
              configuration(button: 0x81, event: 9, action: 17, supported: [2, 21])),
        .init("empty bitmap", [0x80, 9, 14, 0, 0, 0, 0],
              configuration(button: 0x80, event: 9, action: 14, supported: [])),
        .init("lowest bit maps to action 0", [0x80, 9, 14, 0, 0, 0, 1],
              configuration(button: 0x80, event: 9, action: 14, supported: [0])),
        .init("highest bit maps to action 31", [0x80, 9, 14, 0x80, 0, 0, 0],
              configuration(button: 0x80, event: 9, action: 14, supported: [31])),
        .init("every bit set", [0x80, 9, 14, 0xff, 0xff, 0xff, 0xff],
              configuration(button: 0x80, event: 9, action: 14, supported: Set(0...31))),
        .init("unknown event and action are kept open", [0x01, 0x77, 0xfe, 0, 0, 0, 0x02],
              configuration(button: 0x01, event: 0x77, action: 0xfe, supported: [1])),
    ]

    private static let bitmapBoundaries: [DecodeVector<ButtonConfiguration>] = [
        .init("missing bitmap gives no supported actions", [0x80, 9, 19],
              configuration(button: 0x80, event: 9, action: 19, supported: [])),
        .init("fifth bitmap byte is ignored", [0x80, 9, 19, 0, 0, 0, 0x02, 0xff],
              configuration(button: 0x80, event: 9, action: 19, supported: [1])),
    ]

    @Test(arguments: vectors)
    func decodes(_ vector: DecodeVector<ButtonConfiguration>) throws {
        #expect(try BoseFeatures.buttons.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: bitmapBoundaries)
    func bitmapIsAbsentOrFullWithTrailingBytesIgnored(_ vector: DecodeVector<ButtonConfiguration>) throws {
        #expect(try BoseFeatures.buttons.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: [[0x80, 9, 19, 0x02], [0x80, 9, 19, 0x40, 0x0a], [0x80, 9, 19, 0x01, 0x00, 0x00]] as [[UInt8]])
    func bitmapShorterThanFourBytesIsRejected(_ payload: [UInt8]) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.buttons.decode(payload, resolved) }
    }

    @Test(arguments: [[], [0x80, 9]] as [[UInt8]])
    func rejectsPayloadsWithoutAFullAssignment(_ payload: [UInt8]) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.buttons.decode(payload, resolved) }
    }

    @Test func selectableActionsAddTheAssignedActionToTheSupportedSet() {
        let value = Self.configuration(button: 0x80, event: 9, action: 14, supported: [3, 1])
        #expect(value.selectableActions.map(\.rawValue) == [1, 3, 14])
    }
}

struct SourceDecodeVectorTests {
    private static let phone: [UInt8] = [0x64, 0x31, 0x35, 0x81, 0x98, 0x67]

    private static func source(_ kind: UInt8, _ address: [UInt8]? = nil) -> AudioSource {
        AudioSource(kind: AudioSourceKind(rawValue: kind), bluetoothAddress: address.flatMap { BluetoothAddress(bytes: $0) })
    }

    private static let vectors: [DecodeVector<AudioSource>] = [
        .init("captured bluetooth source", [0x00, 0x0f, 0x01] + phone, source(1, phone)),
        .init("first two bytes are ignored", [0xaa, 0xbb, 0x01] + phone, source(1, phone)),
        .init("none", [0x00, 0x00, 0x00], source(0)),
        .init("wired", [0x00, 0x0f, 0x02], source(2)),
        .init("unknown kind is kept open", [0x00, 0x0f, 0x07], source(7)),
        .init("non bluetooth kinds never read an address", [0x00, 0x0f, 0x02] + phone, source(2)),
    ]

    private static let rejected: [RejectedPayload] = [
        .init("empty", []),
        .init("two bytes", [0x00, 0x0f]),
        .init("bluetooth without address", [0x00, 0x0f, 0x01]),
        .init("bluetooth with five address bytes", [0x00, 0x0f, 0x01, 1, 2, 3, 4, 5]),
        .init("bluetooth with bytes after the address", [0x00, 0x0f, 0x01] + phone + [0xde, 0xad]),
    ]

    @Test(arguments: vectors)
    func decodes(_ vector: DecodeVector<AudioSource>) throws {
        #expect(try BoseFeatures.source.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: rejected)
    func rejectsTruncatedAndOverlongPayloads(_ vector: RejectedPayload) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.source.decode(vector.payload, resolved) }
    }
}

struct ModeFeatureDecodeVectorTests {
    private static func favorites(_ slotCount: UInt8, _ slots: Set<UInt8>) -> FavoriteModes {
        do {
            return try FavoriteModes(slotCount: slotCount, slots: slots)
        } catch {
            preconditionFailure("Invalid favorites fixture: \(error)")
        }
    }

    private static let favorites: [DecodeVector<FavoriteModes>] = [
        .init("slots 0 and 2 of 4", [4, 0x00, 0b0101], favorites(4, [0, 2])),
        .init("no slots", [10, 0x00, 0x00], favorites(10, [])),
        .init("zero slot count", [0, 0x00, 0x00], favorites(0, [])),
        .init("first and last of sixteen", [16, 0x80, 0x01], favorites(16, [0, 15])),
        .init("all sixteen", [16, 0xff, 0xff], favorites(16, Set(0...15))),
        .init("mask is big endian across the high byte", [12, 0x08, 0x01], favorites(12, [0, 11])),
        .init("mask bits beyond the slot count are dropped", [4, 0xff, 0xff], favorites(4, [0, 1, 2, 3])),
        .init("bit exactly at the slot count is dropped", [8, 0x01, 0x00], favorites(8, [])),
    ]

    private static let audio: [DecodeVector<AudioSettings>] = [
        .init("every field distinct", [7, 1, 2, 1, 1],
              AudioSettings(cnc: 7, automaticCNC: true, spatial: .motion, windBlock: true, ancEnabled: true)),
        .init("all off with maximum cnc", [10, 0, 0, 0, 0],
              AudioSettings(cnc: 10, automaticCNC: false, spatial: .off, windBlock: false, ancEnabled: false)),
        .init("flags are any non zero byte", [0, 0xff, 1, 0x02, 0x80],
              AudioSettings(cnc: 0, automaticCNC: true, spatial: .still, windBlock: true, ancEnabled: true)),
        .init("anc alone", [3, 0, 0, 0, 1],
              AudioSettings(cnc: 3, automaticCNC: false, spatial: .off, windBlock: false, ancEnabled: true)),
        .init("automatic cnc alone", [4, 1, 0, 0, 0],
              AudioSettings(cnc: 4, automaticCNC: true, spatial: .off, windBlock: false, ancEnabled: false)),
        .init("wind block alone", [5, 0, 0, 1, 0],
              AudioSettings(cnc: 5, automaticCNC: false, spatial: .off, windBlock: true, ancEnabled: false)),
        .init("spatial still", [1, 0, 1, 0, 0],
              AudioSettings(cnc: 1, automaticCNC: false, spatial: .still, windBlock: false, ancEnabled: false)),
    ]

    @Test(arguments: favorites)
    func favoritesDecode(_ vector: DecodeVector<FavoriteModes>) throws {
        #expect(try BoseFeatures.favorites.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: [[], [4, 0], [17, 0, 0], [255, 0xff, 0xff]] as [[UInt8]])
    func favoritesRejectShortPayloadsAndSlotCountsAboveSixteen(_ payload: [UInt8]) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.favorites.decode(payload, resolved) }
    }

    @Test(arguments: [[0], [1], [9], [255]] as [[UInt8]])
    func defaultModeIsTheFirstByte(_ payload: [UInt8]) throws {
        #expect(try BoseFeatures.defaultMode.decode(payload, wireProfile()) == payload[0])
    }

    @Test func defaultModeRejectsEmptyPayload() throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.defaultMode.decode([], resolved) }
    }

    @Test(arguments: audio)
    func audioSettingsDecode(_ vector: DecodeVector<AudioSettings>) throws {
        #expect(try BoseFeatures.audioSettings.decode(vector.payload, wireProfile()) == vector.expected)
    }

    @Test(arguments: [
        [], [7, 1, 2, 1], [11, 0, 0, 0, 0], [255, 0, 0, 0, 0], [0, 0, 3, 0, 0], [0, 0, 0xff, 0, 0],
    ] as [[UInt8]])
    func audioSettingsRejectShortPayloadsAndOutOfRangeFields(_ payload: [UInt8]) throws {
        let resolved = try wireProfile()
        expectInvalidPayload { try BoseFeatures.audioSettings.decode(payload, resolved) }
    }
}

struct SourceDeviceCodecVectorTests {
    private static let list: [UInt8] = [
        0x03, 0x64, 0x31, 0x35, 0x81, 0x98, 0x67, 0xbc, 0xd0, 0x74, 0x72, 0x78, 0x52,
        0x1c, 0xf6, 0x4c, 0x52, 0x34, 0xcb,
    ]
    private static let lemon: [UInt8] = [0x64, 0x31, 0x35, 0x81, 0x98, 0x67]

    @Test func capturedListDecodesToAddressesInWireOrder() throws {
        let addresses = try SourceDeviceCodec.decodeList(Self.list)
        #expect(addresses.map(\.description) == ["64:31:35:81:98:67", "BC:D0:74:72:78:52", "1C:F6:4C:52:34:CB"])
    }

    @Test func listLeadingByteIsNotValidated() throws {
        #expect(try SourceDeviceCodec.decodeList([0xff] + Self.list.dropFirst()).count == 3)
    }

    @Test func listWithOnlyTheLeadingByteIsEmpty() throws {
        #expect(try SourceDeviceCodec.decodeList([0x00]).isEmpty)
    }

    @Test(arguments: [[], [0x01, 1, 2, 3, 4, 5], [0x01, 1, 2, 3, 4, 5, 6, 7]] as [[UInt8]])
    func listRejectsMisalignedPayloads(_ payload: [UInt8]) {
        expectInvalidPayload { try SourceDeviceCodec.decodeList(payload) }
    }

    @Test func capturedInfoDecodesEveryField() throws {
        let source = try address("64:31:35:81:98:67")
        let device = try SourceDeviceCodec.decodeInfo(
            Self.lemon + [0x01, 0x02, 0x03] + Array("lemon".utf8), for: source, activeSource: source)
        #expect(device == SourceDevice(address: source, name: "lemon", isConnected: true,
                                       isRequestingHost: false, isActiveSource: true))
    }

    private struct StatusVector: Sendable, CustomTestStringConvertible {
        let status: UInt8
        let connected: Bool
        let requestingHost: Bool
        var testDescription: String { "status \(status)" }
    }

    private static let statusVectors = [
        StatusVector(status: 0x00, connected: false, requestingHost: false),
        StatusVector(status: 0x01, connected: true, requestingHost: false),
        StatusVector(status: 0x02, connected: false, requestingHost: true),
        StatusVector(status: 0x03, connected: true, requestingHost: true),
        StatusVector(status: 0x04, connected: false, requestingHost: false),
        StatusVector(status: 0xfc, connected: false, requestingHost: false),
        StatusVector(status: 0xff, connected: true, requestingHost: true),
    ]

    @Test(arguments: statusVectors)
    private func infoStatusByteBitsAreConnectedAndRequestingHost(_ vector: StatusVector) throws {
        let source = try address("BC:D0:74:72:78:52")
        let device = try SourceDeviceCodec.decodeInfo(
            source.bytes + [vector.status, 0x02, 0x03] + Array("juicer".utf8), for: source, activeSource: nil)
        #expect(device.isConnected == vector.connected)
        #expect(device.isRequestingHost == vector.requestingHost)
        #expect(!device.isActiveSource)
    }

    @Test func infoWithoutNameDecodesEmptyName() throws {
        let source = try address("64:31:35:81:98:67")
        let device = try SourceDeviceCodec.decodeInfo(Self.lemon + [0, 0, 0], for: source, activeSource: nil)
        #expect(device.name == "")
    }

    @Test func infoNameWithInvalidUTF8IsRejected() throws {
        let source = try address("64:31:35:81:98:67")
        expectInvalidPayload {
            try SourceDeviceCodec.decodeInfo(Self.lemon + [0, 0, 0, 0x41, 0xff], for: source, activeSource: nil)
        }
    }

    @Test func infoActiveSourceComparesAgainstTheRequestedAddress() throws {
        let source = try address("64:31:35:81:98:67")
        let other = try address("BC:D0:74:72:78:52")
        let device = try SourceDeviceCodec.decodeInfo(Self.lemon + [0, 0, 0], for: source, activeSource: other)
        #expect(!device.isActiveSource)
    }

    @Test func infoRejectsAddressMismatchAndShortPayloads() throws {
        let source = try address("64:31:35:81:98:67")
        let other = try address("BC:D0:74:72:78:52")
        expectInvalidPayload {
            try SourceDeviceCodec.decodeInfo(other.bytes + [1, 2, 3], for: source, activeSource: nil)
        }
        expectInvalidPayload {
            try SourceDeviceCodec.decodeInfo(Self.lemon + [1, 2], for: source, activeSource: nil)
        }
        expectInvalidPayload { try SourceDeviceCodec.decodeInfo([], for: source, activeSource: nil) }
    }
}
