public struct ModeConfiguration: Equatable, Sendable, Identifiable {
    public let id: UInt8
    public let prompt: UInt16
    public let name: String
    public let editable: Bool
    public let configured: Bool
    public let favorite: Bool
    public let audio: AudioSettings?
    public let rawPayload: [UInt8]

    public init(id: UInt8, prompt: UInt16, name: String, editable: Bool, configured: Bool,
                favorite: Bool, audio: AudioSettings?, rawPayload: [UInt8]) {
        self.id = id
        self.prompt = prompt
        self.name = name
        self.editable = editable
        self.configured = configured
        self.favorite = favorite
        self.audio = audio
        self.rawPayload = rawPayload
    }
}

public struct ModeDraft: Equatable, Sendable {
    public var slot: UInt8
    public var prompt: UInt16
    public var name: String
    public var audio: AudioSettings

    public init(slot: UInt8, prompt: UInt16, name: String, audio: AudioSettings) {
        self.slot = slot
        self.prompt = prompt
        self.name = name
        self.audio = audio
    }
}
