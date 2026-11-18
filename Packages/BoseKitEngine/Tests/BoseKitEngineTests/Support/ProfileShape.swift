@testable import BoseKitEngine

struct ProfileShape: Equatable, Sendable, CustomStringConvertible {
    enum Battery: Equatable, Sendable {
        case percentage
        case components(aggregate: BatteryComponent, fallback: Set<BatteryComponent>)
    }

    struct Modes: Equatable, Sendable {
        var layout: StandardModeCodec.Layout?
        var editableSlots: Set<UInt8>
        var presetSlots: Set<UInt8> = []
        var expectedSlots: Set<UInt8>?
        var allowsCustomAutoCNC = true
        var windForcesMaximumANC = false
        var deletionCNC: CNCLevel = .minimum
        var deletionClearsConfigured = false
    }

    var id: String
    var name: String
    var productIDs: Set<UInt16>
    var rfcommChannel: RFCOMMChannel
    var initialization: [[UInt8]] = []
    var readOnly: Set<FeatureID>
    var readWrite: Set<FeatureID>
    var otherAccess: [FeatureID: UInt8] = [:]
    var noiseControl: NoiseControlStrategy = .unavailable
    var modes: Modes?
    var battery: Battery = .percentage
    var voicePromptToggleHasSideEffect = false

    var description: String { id }

    init(
        id: String, name: String, productIDs: Set<UInt16>, rfcommChannel: RFCOMMChannel, initialization: [[UInt8]] = [],
        readOnly: Set<FeatureID>, readWrite: Set<FeatureID>, noiseControl: NoiseControlStrategy = .unavailable,
        modes: Modes? = nil, battery: Battery = .percentage, voicePromptToggleHasSideEffect: Bool = false
    ) {
        self.id = id
        self.name = name
        self.productIDs = productIDs
        self.rfcommChannel = rfcommChannel
        self.initialization = initialization
        self.readOnly = readOnly
        self.readWrite = readWrite
        self.noiseControl = noiseControl
        self.modes = modes
        self.battery = battery
        self.voicePromptToggleHasSideEffect = voicePromptToggleHasSideEffect
    }

    init(_ profile: DeviceProfile) {
        id = profile.id
        name = profile.name
        productIDs = profile.productIDs
        rfcommChannel = profile.rfcommChannel
        initialization = profile.initialization.map(\.bytes)
        readOnly = Set(profile.features.filter { $0.value == .read }.keys)
        readWrite = Set(profile.features.filter { $0.value == .readWrite }.keys)
        otherAccess = profile.features.filter { $0.value != .read && $0.value != .readWrite }.mapValues(\.rawValue)
        noiseControl = profile.noiseControl
        modes = profile.modePolicy.map { policy in
            Modes(
                layout: (policy.codec as? StandardModeCodec)?.layout, editableSlots: policy.editableSlots,
                presetSlots: policy.presetSlots, expectedSlots: policy.expectedSlots,
                allowsCustomAutoCNC: policy.allowsCustomAutoCNC, windForcesMaximumANC: policy.windForcesMaximumANC,
                deletionCNC: policy.deletionCNC, deletionClearsConfigured: policy.deletionClearsConfigured
            )
        }
        switch profile.batteryLayout {
        case .percentage: battery = .percentage
        case let .components(aggregate, fallback): battery = .components(aggregate: aggregate, fallback: fallback)
        }
        voicePromptToggleHasSideEffect = profile.voicePromptToggleHasSideEffect
    }
}

extension ProfileShape {
    private static let legacyInitialization: [UInt8] = [0, 1, 1, 0]

    private static let fullModes = Modes(
        layout: .status48, editableSlots: Set(4...10), presetSlots: Set(0...3), expectedSlots: Set(0...10)
    )

    private static let fourSlotModes = Modes(
        layout: .status47, editableSlots: [2, 3], presetSlots: [0, 1], windForcesMaximumANC: true
    )

    private static let modernReadOnly: Set<FeatureID> = [.battery, .firmware, .cnc, .source]

    private static let modernReadWrite: Set<FeatureID> = [
        .name, .voicePrompts, .equalizer, .buttons, .multipoint, .sidetone, .autoPause, .autoAnswer, .pairing,
        .routing, .power, .modes, .currentMode, .defaultMode, .favorites, .audioSettings, .spatialAudio, .windBlock,
        .ancToggle,
    ]

    static let standard: [ProfileShape] = [
        ProfileShape(
            id: "qc35", name: "QuietComfort 35 / 35 II", productIDs: [0x400c, 0x4020], rfcommChannel: 8,
            initialization: [legacyInitialization], readOnly: [.battery, .firmware],
            readWrite: [.name, .voicePrompts, .sidetone, .buttons, .pairing, .anr], noiseControl: .anr
        ),
        ProfileShape(
            id: "wolverine",
            name: "QuietComfort Ultra Headphones (2nd Gen) / QuietComfort Headphones (2nd Gen)",
            productIDs: [0x4082, 0x4083], rfcommChannel: 2, readOnly: modernReadOnly, readWrite: modernReadWrite,
            noiseControl: .audioSettings, modes: fullModes
        ),
        ProfileShape(
            id: "edith", name: "QuietComfort Ultra Earbuds (2nd Gen)", productIDs: [0x4062], rfcommChannel: 2,
            readOnly: modernReadOnly, readWrite: modernReadWrite, noiseControl: .audioSettings, modes: fullModes,
            battery: .components(aggregate: .overall, fallback: [.right, .left])
        ),
        ProfileShape(
            id: "prince", name: "QuietComfort Headphones", productIDs: [0x4075], rfcommChannel: 8,
            readOnly: [.battery, .firmware, .cnc],
            readWrite: [.name, .voicePrompts, .equalizer, .pairing, .modes, .currentMode, .windBlock],
            noiseControl: .modeConfiguration, modes: fourSlotModes
        ),
        ProfileShape(
            id: "duran", name: "QuietComfort 45", productIDs: [0x4039], rfcommChannel: 8,
            initialization: [legacyInitialization], readOnly: [.battery, .firmware, .cnc],
            readWrite: [.name, .voicePrompts, .equalizer, .buttons, .multipoint, .sidetone, .pairing, .modes,
                        .currentMode, .defaultMode, .favorites, .windBlock],
            noiseControl: .modeConfiguration, modes: fourSlotModes
        ),
        ProfileShape(
            id: "lando", name: "QuietComfort Earbuds", productIDs: [0x402f], rfcommChannel: 8,
            readOnly: [.battery, .firmware, .source, .modes],
            readWrite: [.name, .voicePrompts, .cnc, .equalizer, .buttons, .multipoint, .sidetone, .pairing,
                        .routing, .power, .currentMode, .defaultMode, .favorites],
            noiseControl: .directCNC,
            modes: Modes(layout: .status44, editableSlots: [], presetSlots: Set(0...3), expectedSlots: Set(0...3))
        ),
        ProfileShape(
            id: "serena", name: "Ultra Open Earbuds", productIDs: [0x4068], rfcommChannel: 2,
            readOnly: [.battery, .firmware, .source, .modes],
            readWrite: [.name, .voicePrompts, .equalizer, .multipoint, .pairing, .power, .currentMode],
            modes: Modes(layout: .status48, editableSlots: [])
        ),
        ProfileShape(
            id: "goodyear", name: "Noise Cancelling Headphones 700", productIDs: [0x4024], rfcommChannel: 8,
            initialization: [[9, 2, 2, 5, 1, 0, 5, 2, 0x37]],
            readOnly: [.battery, .firmware, .name, .equalizer, .buttons, .multipoint, .sidetone], readWrite: [.cnc],
            noiseControl: .directCNC
        ),
        ProfileShape(
            id: "lonestarr", name: "QuietComfort Ultra Headphones", productIDs: [0x4066], rfcommChannel: 2,
            readOnly: [.battery, .firmware, .serial, .model, .cnc, .source, .sourceDevices],
            readWrite: [.name, .voicePrompts, .equalizer, .buttons, .multipoint, .sidetone, .autoPause, .autoAnswer,
                        .pairing, .power, .modes, .currentMode, .favorites, .spatialAudio, .windBlock],
            noiseControl: .modeConfiguration,
            modes: Modes(
                layout: .status47, editableSlots: Set(3...9), presetSlots: Set(0...2), expectedSlots: Set(0...9),
                allowsCustomAutoCNC: false, windForcesMaximumANC: true, deletionCNC: 10, deletionClearsConfigured: true
            ),
            voicePromptToggleHasSideEffect: true
        ),
    ]
}
