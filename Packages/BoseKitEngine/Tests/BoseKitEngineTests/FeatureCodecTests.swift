import Testing
@testable import BoseKitEngine

struct FeatureCodecTests {
    @Test func signedEQAndMalformedRecords() throws {
        let feature = BoseFeatures.equalizer
        let bands = try feature.decode([246, 10, 251, 0], .lonestarr)
        #expect(bands.first?.range == -10...10)
        #expect(bands.first?.value == -5)
        #expect(try feature.encode(EQAdjustment(band: 0, value: -5), .lonestarr) == [251, 0])
        #expect(throws: BoseError.self) { try feature.decode([246, 10, 0], .lonestarr) }
    }

    @Test func multipointUsesEnabledBit() throws {
        #expect(try BoseFeatures.multipoint.decode([7], .lonestarr))
        #expect(try !BoseFeatures.multipoint.decode([6], .lonestarr))
    }

    @Test func shortcutBitmapUsesBigEndian() throws {
        let value = try BoseFeatures.buttons.decode([0x80, 9, 19, 0, 9, 0x40, 0x0a], .lonestarr)
        #expect(Set(value.supportedActions.map(\.rawValue)) == [1, 3, 14, 16, 19])
        #expect(value.assignment.event == .longPress)
    }

    @Test func voicePromptsPreserveHighBits() throws {
        var value = try BoseFeatures.voicePrompts.decode([0xe1, 0, 0, 0, 0, 0, 1], .lonestarr)
        value.enabled = false
        #expect(try BoseFeatures.voicePrompts.encode(value, .lonestarr) == [0xc1])
        value.enabled = true
        #expect(try BoseFeatures.voicePrompts.encode(value, .lonestarr) == [0xe1])
    }

    @Test func componentBatteryFallback() throws {
        let value = try BoseFeatures.battery.decode([80, 0, 0, 1, 65, 0, 0, 2, 255, 0, 0, 4], .edith)
        #expect(value.percentage == 65)
        #expect(value.components == [.right: 80, .left: 65])
        #expect(throws: BoseError.self) {
            try BoseFeatures.battery.decode([80, 0, 0, 1, 70, 0, 0, 1], .edith)
        }
    }

    @Test func favoritesRoundTripThroughSlotMask() throws {
        let decoded = try BoseFeatures.favorites.decode([4, 0, 0b0101], .lonestarr)
        #expect(try decoded == FavoriteModes(slotCount: 4, slots: [0, 2]))
        #expect(try BoseFeatures.favorites.encode(decoded, .lonestarr) == [4, 0, 0b0101])
    }

    @Test func favoritesRejectSlotsBeyondCount() throws {
        #expect(throws: BoseError.self) { try FavoriteModes(slotCount: 4, slots: [4]) }
    }
}
