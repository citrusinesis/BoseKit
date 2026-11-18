extension DeviceRegistry {
    public static func standard() throws -> Self {
        let upstream = "bosectl 5de5b7ee9b6d096a817a5f5eeb4178f39ed70774; hardware not retested in Swift"
        let common: [FeatureID: FeatureAccess] = [.battery: .read, .firmware: .read, .name: .readWrite]
        func capabilities(read: [FeatureID] = [], write: [FeatureID] = []) -> [FeatureID: FeatureAccess] {
            var result = common
            for id in read { result[id] = .read }
            for id in write { result[id] = .readWrite }
            return result
        }
        let initLegacy = try BMAPPacket(address: .productInfo, operation: .get)
        let legacy = capabilities(write: [.name, .voicePrompts, .sidetone, .buttons, .pairing, .anr])
        let modern = capabilities(
            read: [.cnc, .source],
            write: [.voicePrompts, .equalizer, .buttons, .multipoint, .sidetone,
                    .autoPause, .autoAnswer, .pairing, .routing, .power, .modes,
                    .currentMode, .defaultMode, .favorites, .audioSettings, .spatialAudio, .windBlock, .ancToggle]
        )
        let fullModes = ModePolicy(codec: StandardModeCodec(.status48), editableSlots: Set(4...10), presetSlots: Set(0...3),
                                   expectedSlots: Set(0...10))
        var profiles: [DeviceProfile] = []
        profiles.append(try DeviceProfile(
            id: "qc35", name: "QuietComfort 35 / 35 II", productIDs: [0x400c, 0x4020],
            rfcommChannel: 8, initialization: [initLegacy], features: legacy,
            noiseControl: .anr, provenance: upstream
        ))
        profiles.append(try DeviceProfile(
            id: "wolverine", name: "QuietComfort Ultra Headphones (2nd Gen) / QuietComfort Headphones (2nd Gen)",
            productIDs: [0x4082, 0x4083], rfcommChannel: 2, features: modern,
            noiseControl: .audioSettings, modePolicy: fullModes, provenance: upstream
        ))
        profiles.append(try DeviceProfile(
            id: "edith", name: "QuietComfort Ultra Earbuds (2nd Gen)", productIDs: [0x4062],
            rfcommChannel: 2, features: modern, noiseControl: .audioSettings, modePolicy: fullModes,
            batteryLayout: .components(aggregate: .overall, fallback: [.right, .left]), provenance: upstream
        ))
        profiles.append(try DeviceProfile(
            id: "prince", name: "QuietComfort Headphones", productIDs: [0x4075], rfcommChannel: 8,
            features: capabilities(read: [.cnc], write: [.voicePrompts, .equalizer, .pairing, .modes, .currentMode, .windBlock]),
            noiseControl: .modeConfiguration,
            modePolicy: ModePolicy(codec: StandardModeCodec(.status47), editableSlots: [2, 3], presetSlots: [0, 1],
                                   windForcesMaximumANC: true), provenance: upstream
        ))
        profiles.append(try DeviceProfile(
            id: "duran", name: "QuietComfort 45", productIDs: [0x4039], rfcommChannel: 8,
            initialization: [initLegacy],
            features: capabilities(read: [.cnc], write: [.name, .voicePrompts, .equalizer, .buttons,
                .multipoint, .sidetone, .pairing, .modes, .currentMode, .defaultMode, .favorites, .windBlock]),
            noiseControl: .modeConfiguration,
            modePolicy: ModePolicy(codec: StandardModeCodec(.status47), editableSlots: [2, 3], presetSlots: [0, 1],
                                   windForcesMaximumANC: true), provenance: upstream
        ))
        profiles.append(try DeviceProfile(
            id: "lando", name: "QuietComfort Earbuds", productIDs: [0x402f], rfcommChannel: 8,
            features: capabilities(read: [.source, .modes], write: [.voicePrompts, .cnc, .equalizer,
                .buttons, .multipoint, .sidetone, .pairing, .routing, .power, .currentMode, .defaultMode, .favorites]),
            noiseControl: .directCNC,
            modePolicy: ModePolicy(codec: StandardModeCodec(.status44), editableSlots: [], presetSlots: Set(0...3),
                                   expectedSlots: Set(0...3)), provenance: upstream
        ))
        profiles.append(try DeviceProfile(
            id: "serena", name: "Ultra Open Earbuds", productIDs: [0x4068], rfcommChannel: 2,
            features: capabilities(read: [.source, .modes], write: [.voicePrompts, .equalizer, .multipoint,
                .pairing, .power, .currentMode]),
            modePolicy: ModePolicy(codec: StandardModeCodec(.status48), editableSlots: []),
            provenance: upstream + "; ModeConfig layout inferred upstream"
        ))
        profiles.append(try DeviceProfile(
            id: "goodyear", name: "Noise Cancelling Headphones 700", productIDs: [0x4024], rfcommChannel: 8,
            initialization: [try BMAPPacket(address: .notifications, operation: .setGet,
                                            payload: [1, 0, 5, 2, 0x37])],
            features: capabilities(read: [.name, .equalizer, .buttons, .multipoint, .sidetone], write: [.cnc]),
            noiseControl: .directCNC, provenance: upstream
        ))
        profiles.append(try DeviceProfile(
            id: "lonestarr", name: "QuietComfort Ultra Headphones", productIDs: [0x4066], rfcommChannel: 2,
            features: capabilities(read: [.serial, .model, .cnc, .source, .sourceDevices],
                write: [.name, .voicePrompts, .equalizer, .buttons, .multipoint, .sidetone,
                        .autoPause, .autoAnswer, .pairing, .power, .modes, .currentMode, .favorites, .spatialAudio, .windBlock]),
            noiseControl: .modeConfiguration,
            modePolicy: ModePolicy(codec: StandardModeCodec(.status47), editableSlots: Set(3...9), presetSlots: Set(0...2),
                expectedSlots: Set(0...9), allowsCustomAutoCNC: false, windForcesMaximumANC: true,
                deletionCNC: 10, deletionClearsConfigured: true),
            voicePromptToggleHasSideEffect: true,
            provenance: "User hardware verification 2026-11-17; firmware 1.6.7+g6ebabd2"
        ))
        return try Self(profiles: profiles)
    }
}
