public enum SpatialAudio: UInt8, Sendable, CaseIterable {
    case off = 0, still, motion
}

public struct AudioSettings: Equatable, Sendable {
    public var cnc: UInt8
    public var automaticCNC: Bool
    public var spatial: SpatialAudio
    public var windBlock: Bool
    public var ancEnabled: Bool?

    public init(cnc: UInt8, automaticCNC: Bool = false, spatial: SpatialAudio = .off,
                windBlock: Bool = false, ancEnabled: Bool? = nil) {
        self.cnc = cnc
        self.automaticCNC = automaticCNC
        self.spatial = spatial
        self.windBlock = windBlock
        self.ancEnabled = ancEnabled
    }
}
