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
    public let deletionCNC: UInt8
    public let deletionClearsConfigured: Bool

    public init(
        codec: any ModeCodec, editableSlots: Set<UInt8>, presetSlots: Set<UInt8> = [], expectedSlots: Set<UInt8>? = nil,
        allowsCustomAutoCNC: Bool = true, windForcesMaximumANC: Bool = false,
        deletionCNC: UInt8 = 0, deletionClearsConfigured: Bool = false
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
    public let rfcommChannel: UInt8
    public let initialization: [BMAPPacket]
    public let features: [FeatureID: FeatureAccess]
    public let noiseControl: NoiseControlStrategy
    public let modePolicy: ModePolicy?
    public let batteryLayout: BatteryLayout
    public let buttonBitmapBigEndian: Bool
    public let voicePromptToggleHasSideEffect: Bool
    public let provenance: String

    public init(
        id: String, name: String, productIDs: Set<UInt16>, rfcommChannel: UInt8,
        initialization: [BMAPPacket] = [], features: [FeatureID: FeatureAccess],
        noiseControl: NoiseControlStrategy = .unavailable, modePolicy: ModePolicy? = nil,
        batteryLayout: BatteryLayout = .percentage, buttonBitmapBigEndian: Bool = true,
        voicePromptToggleHasSideEffect: Bool = false,
        provenance: String
    ) throws {
        guard (1...30).contains(rfcommChannel) else {
            throw BoseError.invalidArgument("RFCOMM channel must be 1...30")
        }
        self.id = id
        self.name = name
        self.productIDs = productIDs
        self.rfcommChannel = rfcommChannel
        self.initialization = initialization
        self.features = features
        self.noiseControl = noiseControl
        self.modePolicy = modePolicy
        self.batteryLayout = batteryLayout
        self.buttonBitmapBigEndian = buttonBitmapBigEndian
        self.voicePromptToggleHasSideEffect = voicePromptToggleHasSideEffect
        self.provenance = provenance
    }

    public func supports(_ feature: FeatureID, access: FeatureAccess = .read) -> Bool {
        features[feature]?.contains(access) == true
    }
}
