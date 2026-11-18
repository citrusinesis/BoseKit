extension DeviceProfile {
    public static let qc35 = DeviceProfile(
        id: "qc35", name: "QuietComfort 35 / 35 II", productIDs: [0x400c, 0x4020],
        rfcommChannel: 8, initialization: [legacyInitialization], features: legacyFeatures,
        noiseControl: .anr
    )

    public static let wolverine = DeviceProfile(
        id: "wolverine", name: "QuietComfort Ultra Headphones (2nd Gen) / QuietComfort Headphones (2nd Gen)",
        productIDs: [0x4082, 0x4083], rfcommChannel: 2, features: modernFeatures,
        noiseControl: .audioSettings, modePolicy: fullModes
    )

    public static let edith = DeviceProfile(
        id: "edith", name: "QuietComfort Ultra Earbuds (2nd Gen)", productIDs: [0x4062],
        rfcommChannel: 2, features: modernFeatures, noiseControl: .audioSettings, modePolicy: fullModes,
        batteryLayout: .components(aggregate: .overall, fallback: [.right, .left])
    )

    public static let prince = DeviceProfile(
        id: "prince", name: "QuietComfort Headphones", productIDs: [0x4075], rfcommChannel: 8,
        features: capabilities(read: [.cnc], write: [.voicePrompts, .equalizer, .pairing, .modes, .currentMode, .windBlock]),
        noiseControl: .modeConfiguration, modePolicy: fourSlotModes
    )

    public static let duran = DeviceProfile(
        id: "duran", name: "QuietComfort 45", productIDs: [0x4039], rfcommChannel: 8,
        initialization: [legacyInitialization],
        features: capabilities(read: [.cnc], write: [.voicePrompts, .equalizer, .buttons,
            .multipoint, .sidetone, .pairing, .modes, .currentMode, .defaultMode, .favorites, .windBlock]),
        noiseControl: .modeConfiguration, modePolicy: fourSlotModes
    )

    public static let lando = DeviceProfile(
        id: "lando", name: "QuietComfort Earbuds", productIDs: [0x402f], rfcommChannel: 8,
        features: capabilities(read: [.source, .modes], write: [.voicePrompts, .cnc, .equalizer,
            .buttons, .multipoint, .sidetone, .pairing, .routing, .power, .currentMode, .defaultMode, .favorites]),
        noiseControl: .directCNC,
        modePolicy: ModePolicy(codec: StandardModeCodec(.status44), editableSlots: [], presetSlots: Set(0...3),
                               expectedSlots: Set(0...3))
    )

    public static let serena = DeviceProfile(
        id: "serena", name: "Ultra Open Earbuds", productIDs: [0x4068], rfcommChannel: 2,
        features: capabilities(read: [.source, .modes], write: [.voicePrompts, .equalizer, .multipoint,
            .pairing, .power, .currentMode]),
        modePolicy: ModePolicy(codec: StandardModeCodec(.status48), editableSlots: [])
    )

    public static let goodyear = DeviceProfile(
        id: "goodyear", name: "Noise Cancelling Headphones 700", productIDs: [0x4024], rfcommChannel: 8,
        initialization: [BMAPPacket(address: .notifications, operation: .setGet, uncheckedPayload: [1, 0, 5, 2, 0x37])],
        features: capabilities(read: [.name, .equalizer, .buttons, .multipoint, .sidetone], write: [.cnc]),
        noiseControl: .directCNC
    )

    public static let lonestarr = DeviceProfile(
        id: "lonestarr", name: "QuietComfort Ultra Headphones", productIDs: [0x4066], rfcommChannel: 2,
        features: capabilities(read: [.serial, .model, .cnc, .source, .sourceDevices],
            write: [.voicePrompts, .equalizer, .buttons, .multipoint, .sidetone,
                    .autoPause, .autoAnswer, .pairing, .power, .modes, .currentMode, .favorites, .spatialAudio, .windBlock]),
        noiseControl: .modeConfiguration,
        modePolicy: ModePolicy(codec: StandardModeCodec(.status47), editableSlots: Set(3...9), presetSlots: Set(0...2),
            expectedSlots: Set(0...9), allowsCustomAutoCNC: false, windForcesMaximumANC: true,
            deletionCNC: 10, deletionClearsConfigured: true),
        voicePromptToggleHasSideEffect: true
    )

    private static let legacyInitialization = BMAPPacket(address: .productInfo, operation: .get, uncheckedPayload: [])

    private static let legacyFeatures = capabilities(write: [.voicePrompts, .sidetone, .buttons, .pairing, .anr])

    private static let modernFeatures = capabilities(
        read: [.cnc, .source],
        write: [.voicePrompts, .equalizer, .buttons, .multipoint, .sidetone,
                .autoPause, .autoAnswer, .pairing, .routing, .power, .modes,
                .currentMode, .defaultMode, .favorites, .audioSettings, .spatialAudio, .windBlock, .ancToggle]
    )

    private static let fullModes = ModePolicy(
        codec: StandardModeCodec(.status48), editableSlots: Set(4...10), presetSlots: Set(0...3),
        expectedSlots: Set(0...10)
    )

    private static let fourSlotModes = ModePolicy(
        codec: StandardModeCodec(.status47), editableSlots: [2, 3], presetSlots: [0, 1],
        windForcesMaximumANC: true
    )

    private static func capabilities(read: [FeatureID] = [], write: [FeatureID] = []) -> [FeatureID: FeatureAccess] {
        var result: [FeatureID: FeatureAccess] = [.battery: .read, .firmware: .read, .name: .readWrite]
        for id in read { result[id] = .read }
        for id in write { result[id] = .readWrite }
        return result
    }
}

extension DeviceRegistry {
    public static let standard = DeviceRegistry(uncheckedProfiles: [
        .qc35, .wolverine, .edith, .prince, .duran, .lando, .serena, .goodyear, .lonestarr,
    ])
}
