import Testing
@testable import BoseKitEngine

struct FeatureDescriptorVectorTests {
    private struct Descriptor: Sendable, CustomTestStringConvertible {
        let id: FeatureID
        let address: BMAPAddress
        let writeOperation: BMAPOperator
        let actual: (id: FeatureID, address: BMAPAddress, operation: BMAPOperator)

        init<V, I>(_ feature: BoseFeature<V, I>, _ id: FeatureID, _ block: UInt8, _ function: UInt8,
                   _ operation: BMAPOperator = .setGet) {
            self.id = id
            address = BMAPAddress(block, function)
            writeOperation = operation
            actual = (feature.id, feature.address, feature.writeOperation)
        }

        var testDescription: String { id.rawValue }
    }

    private static let descriptors: [Descriptor] = [
        Descriptor(BoseFeatures.battery, .battery, 2, 2),
        Descriptor(BoseFeatures.name, .name, 1, 2),
        Descriptor(BoseFeatures.firmware, .firmware, 0, 5),
        Descriptor(BoseFeatures.serial, .serial, 0, 7),
        Descriptor(BoseFeatures.model, .model, 0, 15),
        Descriptor(BoseFeatures.cnc, .cnc, 1, 5),
        Descriptor(BoseFeatures.anr, .anr, 1, 6),
        Descriptor(BoseFeatures.equalizer, .equalizer, 1, 7),
        Descriptor(BoseFeatures.multipoint, .multipoint, 1, 10),
        Descriptor(BoseFeatures.autoPause, .autoPause, 1, 24),
        Descriptor(BoseFeatures.autoAnswer, .autoAnswer, 1, 27),
        Descriptor(BoseFeatures.pairing, .pairing, 4, 8, .start),
        Descriptor(BoseFeatures.sidetone, .sidetone, 1, 11),
        Descriptor(BoseFeatures.voicePrompts, .voicePrompts, 1, 3),
        Descriptor(BoseFeatures.buttons, .buttons, 1, 9),
        Descriptor(BoseFeatures.source, .source, 5, 1),
        Descriptor(BoseFeatures.favorites, .favorites, 31, 8),
        Descriptor(BoseFeatures.defaultMode, .defaultMode, 31, 4),
        Descriptor(BoseFeatures.audioSettings, .audioSettings, 31, 10),
    ]

    @Test(arguments: descriptors)
    private func featureUsesItsWireAddressAndWriteOperation(_ descriptor: Descriptor) {
        #expect(descriptor.actual.id == descriptor.id)
        #expect(descriptor.actual.address == descriptor.address)
        #expect(descriptor.actual.operation == descriptor.writeOperation)
    }

    @Test func addressConstantsPinTheirBlockAndFunction() {
        let expected: [(BMAPAddress, UInt8, UInt8)] = [
            (.productInfo, 0, 1), (.firmware, 0, 5), (.serial, 0, 7), (.model, 0, 15),
            (.name, 1, 2), (.voicePrompts, 1, 3), (.cnc, 1, 5), (.anr, 1, 6), (.equalizer, 1, 7),
            (.buttons, 1, 9), (.multipoint, 1, 10), (.sidetone, 1, 11), (.autoPause, 1, 24),
            (.autoAnswer, 1, 27), (.battery, 2, 2), (.deviceList, 4, 4), (.deviceInfo, 4, 5),
            (.pairing, 4, 8), (.routing, 4, 12), (.source, 5, 1), (.power, 7, 4),
            (.notifications, 9, 2), (.modeList, 31, 1), (.modeIndices, 31, 2), (.currentMode, 31, 3),
            (.defaultMode, 31, 4), (.modeConfiguration, 31, 6), (.favorites, 31, 8),
            (.audioSettings, 31, 10),
        ]
        for (address, block, function) in expected {
            #expect(address == BMAPAddress(block, function), "\(block),\(function)")
        }
    }
}

struct FeatureEncodeVectorTests {
    private static func prompts(flags: UInt8, enabled: Bool, language: VoicePromptLanguage) -> VoicePrompts {
        var value = VoicePrompts(flags: flags)
        value.enabled = enabled
        value.language = language
        return value
    }

    private static func favorites(_ slotCount: UInt8, _ slots: Set<UInt8>) -> FavoriteModes {
        do {
            return try FavoriteModes(slotCount: slotCount, slots: slots)
        } catch {
            preconditionFailure("Invalid favorites fixture: \(error)")
        }
    }

    private static let name: [EncodeVector<DeviceName>] = [
        .init("ascii name", "Citrus QC", Array("Citrus QC".utf8)),
        .init("single byte name", "a", [0x61]),
        .init("multibyte name", "한글 🎧", Array("한글 🎧".utf8)),
        .init("ten korean syllables fit in thirty bytes", "한한한한한한한한한한",
              Array(String(repeating: "한", count: 10).utf8)),
        .init("thirty one byte name is the maximum", "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz",
              Array(repeating: 0x7a, count: 31)),
    ]

    private static let cnc: [EncodeVector<CNCLevel>] = [
        .init("level 0", 0, [0, 1]),
        .init("level 6", 6, [6, 1]),
        .init("level 10", 10, [10, 1]),
    ]

    private static let anr: [EncodeVector<ANRLevel>] = [
        .init("off", .off, [0]), .init("high", .high, [1]), .init("wind", .wind, [2]), .init("low", .low, [3]),
    ]

    private static let sidetone: [EncodeVector<SidetoneLevel>] = [
        .init("off", .off, [1, 0]), .init("high", .high, [1, 1]),
        .init("medium", .medium, [1, 2]), .init("low", .low, [1, 3]),
    ]

    private static let equalizer: [EncodeVector<EQAdjustment>] = [
        .init("band 3 at +4", EQAdjustment(band: 3, value: 4), [4, 3]),
        .init("band 0 at -5", EQAdjustment(band: 0, value: -5), [251, 0]),
        .init("band 7 at zero", EQAdjustment(band: 7, value: 0), [0, 7]),
        .init("most negative value", EQAdjustment(band: 1, value: -128), [128, 1]),
        .init("most positive value", EQAdjustment(band: 2, value: 127), [127, 2]),
        .init("minus one", EQAdjustment(band: 9, value: -1), [255, 9]),
    ]

    private static let voicePrompts: [EncodeVector<VoicePrompts>] = [
        .init("disable keeps high bits and language",
              prompts(flags: 0xe1, enabled: false, language: .englishUS), [0xc1]),
        .init("enable keeps high bits and language",
              prompts(flags: 0xc1, enabled: true, language: .englishUS), [0xe1]),
        .init("language change keeps enabled and high bits",
              prompts(flags: 0xa1, enabled: true, language: .korean), [0xa9]),
        .init("clear high bits stay clear",
              prompts(flags: 0x3f, enabled: false, language: .spanish), [0x05]),
        .init("raw enabled bit is replaced by the value",
              prompts(flags: 0x20, enabled: false, language: .englishUK), [0x00]),
        .init("raw language bits are replaced by the value",
              prompts(flags: 0x1f, enabled: false, language: .englishUK), [0x00]),
        .init("everything set",
              prompts(flags: 0xff, enabled: true, language: VoicePromptLanguage(bits: 31)), [0xff]),
    ]

    private static let buttons: [EncodeVector<ButtonAssignment>] = [
        .init("long press cycles modes",
              ButtonAssignment(button: 0x80, event: .longPress, action: .cycleModes), [0x80, 9, 17]),
        .init("unknown raw values are written verbatim",
              ButtonAssignment(button: 0x01, event: ButtonEvent(rawValue: 0x77), action: ButtonAction(rawValue: 0xfe)),
              [0x01, 0x77, 0xfe]),
    ]

    private static let favorites: [EncodeVector<FavoriteModes>] = [
        .init("slots 0 and 2 of 4", favorites(4, [0, 2]), [4, 0x00, 0b0101]),
        .init("no slots", favorites(10, []), [10, 0x00, 0x00]),
        .init("first and last of sixteen", favorites(16, [0, 15]), [16, 0x80, 0x01]),
        .init("slots 8 and 9 land in the high byte", favorites(10, [8, 9]), [10, 0x03, 0x00]),
        .init("all sixteen", favorites(16, Set(0...15)), [16, 0xff, 0xff]),
        .init("zero slot count", favorites(0, []), [0, 0x00, 0x00]),
    ]

    private static let audio: [EncodeVector<AudioSettings>] = [
        .init("every field distinct",
              AudioSettings(cnc: 7, automaticCNC: true, spatial: .motion, windBlock: true, ancEnabled: true),
              [7, 1, 2, 1, 1]),
        .init("all off",
              AudioSettings(cnc: 0, automaticCNC: false, spatial: .off, windBlock: false, ancEnabled: false),
              [0, 0, 0, 0, 0]),
        .init("anc off with others on",
              AudioSettings(cnc: 10, automaticCNC: true, spatial: .still, windBlock: true, ancEnabled: false),
              [10, 1, 1, 1, 0]),
    ]

    @Test(arguments: name)
    func nameEncodes(_ vector: EncodeVector<DeviceName>) throws {
        #expect(try BoseFeatures.name.encode(vector.input, wireProfile(vector.product)) == vector.expected)
    }

    @Test(arguments: [
        "", String(repeating: "z", count: 32), String(repeating: "한", count: 11), "bad\0name", "\0",
    ])
    func invalidNameCannotBeConstructed(_ value: String) {
        #expect(DeviceName(rawValue: value) == nil)
    }

    @Test(arguments: cnc)
    func cncEncodes(_ vector: EncodeVector<CNCLevel>) throws {
        #expect(try BoseFeatures.cnc.encode(vector.input, wireProfile()) == vector.expected)
    }

    @Test(arguments: [UInt8(11), 255])
    func cncLevelAboveMaximumCannotBeConstructed(_ level: UInt8) {
        #expect(CNCLevel(rawValue: level) == nil)
    }

    @Test(arguments: anr)
    func anrEncodes(_ vector: EncodeVector<ANRLevel>) throws {
        #expect(try BoseFeatures.anr.encode(vector.input, wireProfile()) == vector.expected)
    }

    @Test(arguments: sidetone)
    func sidetoneEncodes(_ vector: EncodeVector<SidetoneLevel>) throws {
        #expect(try BoseFeatures.sidetone.encode(vector.input, wireProfile()) == vector.expected)
    }

    @Test(arguments: equalizer)
    func equalizerEncodes(_ vector: EncodeVector<EQAdjustment>) throws {
        #expect(try BoseFeatures.equalizer.encode(vector.input, wireProfile()) == vector.expected)
    }

    @Test(arguments: [true, false])
    func everyToggleEncodesOneOrZero(_ value: Bool) throws {
        let resolved = try wireProfile()
        let features = [BoseFeatures.multipoint, BoseFeatures.autoPause, BoseFeatures.autoAnswer, BoseFeatures.pairing]
        for feature in features {
            #expect(try feature.encode(value, resolved) == [value ? 1 : 0], "\(feature.id.rawValue)")
        }
    }

    @Test(arguments: voicePrompts)
    func voicePromptsEncode(_ vector: EncodeVector<VoicePrompts>) throws {
        #expect(try BoseFeatures.voicePrompts.encode(vector.input, wireProfile()) == vector.expected)
    }

    @Test func voicePromptLanguageAboveFiveBitsCannotBeConstructed() {
        #expect(VoicePromptLanguage(rawValue: 31) != nil)
        #expect(VoicePromptLanguage(rawValue: 32) == nil)
        #expect(VoicePromptLanguage(rawValue: 0xff) == nil)
    }

    @Test(arguments: buttons)
    func buttonsEncode(_ vector: EncodeVector<ButtonAssignment>) throws {
        #expect(try BoseFeatures.buttons.encode(vector.input, wireProfile()) == vector.expected)
    }

    @Test(arguments: favorites)
    func favoritesEncode(_ vector: EncodeVector<FavoriteModes>) throws {
        #expect(try BoseFeatures.favorites.encode(vector.input, wireProfile()) == vector.expected)
    }

    @Test(arguments: [(17, []), (4, [4]), (16, [16]), (0, [0])] as [(UInt8, Set<UInt8>)])
    func invalidFavoritesCannotBeConstructed(_ slotCount: UInt8, _ slots: Set<UInt8>) {
        expectInvalidArgument { try FavoriteModes(slotCount: slotCount, slots: slots) }
    }

    @Test func defaultModeEncodesTheSlotWhenTheProfileExpectsIt() throws {
        #expect(try BoseFeatures.defaultMode.encode(5, wireProfile(0x4066)) == [5])
        #expect(try BoseFeatures.defaultMode.encode(9, wireProfile(0x4066)) == [9])
        #expect(try BoseFeatures.defaultMode.encode(3, wireProfile(0x402f)) == [3])
    }

    @Test func defaultModeWithoutExpectedSlotsAcceptsAnyByte() throws {
        #expect(try BoseFeatures.defaultMode.encode(200, wireProfile(0x4075)) == [200])
        #expect(try BoseFeatures.defaultMode.encode(0, wireProfile(0x4024)) == [0])
    }

    @Test func defaultModeRejectsSlotsOutsideTheExpectedSet() throws {
        let lonestarr = try wireProfile(0x4066)
        let lando = try wireProfile(0x402f)
        expectInvalidArgument { try BoseFeatures.defaultMode.encode(10, lonestarr) }
        expectInvalidArgument { try BoseFeatures.defaultMode.encode(4, lando) }
    }

    @Test(arguments: audio)
    func audioSettingsEncode(_ vector: EncodeVector<AudioSettings>) throws {
        #expect(try BoseFeatures.audioSettings.encode(vector.input, wireProfile()) == vector.expected)
    }

    @Test func audioSettingsRejectMissingANC() throws {
        let resolved = try wireProfile()
        expectInvalidArgument { try BoseFeatures.audioSettings.encode(AudioSettings(cnc: 3), resolved) }
    }
}
