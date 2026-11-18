public enum NoiseControlStrategy: Sendable {
    case unavailable, anr, directCNC, audioSettings, modeConfiguration
}

public struct ModePolicy: Sendable {
    public let codec: any ModeCodec
    public let editableSlots: Set<UInt8>
    public let presetSlots: Set<UInt8>
    public let expectedSlots: Set<UInt8>?
    public let allowsCustomAutoCNC: Bool
    public let windForcesMaximumANC: Bool
    public let deletionCNC: CNCLevel
    public let deletionClearsConfigured: Bool

    public init(
        codec: any ModeCodec, editableSlots: Set<UInt8>, presetSlots: Set<UInt8> = [], expectedSlots: Set<UInt8>? = nil,
        allowsCustomAutoCNC: Bool = true, windForcesMaximumANC: Bool = false,
        deletionCNC: CNCLevel = .minimum, deletionClearsConfigured: Bool = false
    ) {
        self.codec = codec
        self.editableSlots = editableSlots
        self.presetSlots = presetSlots
        self.expectedSlots = expectedSlots
        self.allowsCustomAutoCNC = allowsCustomAutoCNC
        self.windForcesMaximumANC = windForcesMaximumANC
        self.deletionCNC = deletionCNC
        self.deletionClearsConfigured = deletionClearsConfigured
    }

    public func isSelectable(_ mode: ModeConfiguration) -> Bool {
        mode.configured || presetSlots.contains(mode.id)
    }

    public var fallbackPreset: UInt8? { presetSlots.min() }
}

public struct DeviceProfile: Sendable {
    public let id: String
    public let name: String
    public let productIDs: Set<UInt16>
    public let rfcommChannel: RFCOMMChannel
    public let initialization: [BMAPPacket]
    public let features: [FeatureID: FeatureAccess]
    public let noiseControl: NoiseControlStrategy
    public let modePolicy: ModePolicy?
    public let batteryLayout: BatteryLayout
    public let voicePromptToggleHasSideEffect: Bool

    public init(
        id: String, name: String, productIDs: Set<UInt16>, rfcommChannel: RFCOMMChannel,
        initialization: [BMAPPacket] = [], features: [FeatureID: FeatureAccess],
        noiseControl: NoiseControlStrategy = .unavailable, modePolicy: ModePolicy? = nil,
        batteryLayout: BatteryLayout = .percentage,
        voicePromptToggleHasSideEffect: Bool = false
    ) {
        self.id = id
        self.name = name
        self.productIDs = productIDs
        self.rfcommChannel = rfcommChannel
        self.initialization = initialization
        self.features = features
        self.noiseControl = noiseControl
        self.modePolicy = modePolicy
        self.batteryLayout = batteryLayout
        self.voicePromptToggleHasSideEffect = voicePromptToggleHasSideEffect
    }

    public func supports(_ feature: FeatureID, access: FeatureAccess = .read) -> Bool {
        features[feature]?.contains(access) == true
    }
}
