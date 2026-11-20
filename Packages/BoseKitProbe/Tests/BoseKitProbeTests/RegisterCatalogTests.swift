import BoseKitEngine
import Testing
@testable import BoseKitProbe

struct RegisterCatalogTests {
    @Test func everyKnownEngineAddressHasAName() {
        let known: [BMAPAddress] = [
            .productInfo, .firmware, .serial, .model, .name, .voicePrompts, .cnc, .anr, .equalizer, .buttons,
            .multipoint, .sidetone, .autoPause, .autoAnswer, .battery, .deviceList, .deviceInfo, .pairing, .routing,
            .source, .power, .notifications, .modeList, .modeIndices, .currentMode, .defaultMode,
            .modeConfiguration, .favorites, .audioSettings,
        ]
        #expect(known.allSatisfy { RegisterCatalog.names[$0] != nil })
    }

    @Test func columnsHaveTheSameWidthForKnownAndUnknownAddresses() {
        let widths = [BMAPAddress(31, 11), BMAPAddress(2, 2), BMAPAddress(200, 200), BMAPAddress(1, 16)]
            .map { RegisterCatalog.column(for: $0).count }
        #expect(Set(widths).count == 1)
    }

    @Test func columnShowsTheNameAfterTheAddress() {
        #expect(RegisterCatalog.column(for: .battery).hasPrefix("[2.2]   battery "))
    }
}
