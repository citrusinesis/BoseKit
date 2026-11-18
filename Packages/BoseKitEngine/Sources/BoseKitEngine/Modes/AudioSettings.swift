public enum SpatialAudio: UInt8, Sendable, CaseIterable {
    case off = 0, still, motion

    init(decoding rawValue: UInt8) throws {
        guard let spatial = Self(rawValue: rawValue) else {
            throw BoseError.invalidPayload("Unknown spatial audio mode \(rawValue)")
        }
        self = spatial
    }
}

public struct AudioSettings: Equatable, Sendable {
    public var cnc: CNCLevel
    public var automaticCNC: Bool
    public var spatial: SpatialAudio
    public var windBlock: Bool
    public var ancEnabled: Bool?

    public init(cnc: CNCLevel, automaticCNC: Bool = false, spatial: SpatialAudio = .off,
                windBlock: Bool = false, ancEnabled: Bool? = nil) {
        self.cnc = cnc
        self.automaticCNC = automaticCNC
        self.spatial = spatial
        self.windBlock = windBlock
        self.ancEnabled = ancEnabled
    }
}
