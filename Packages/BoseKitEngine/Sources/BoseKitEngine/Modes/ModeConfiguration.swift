public struct ModeConfiguration: Equatable, Sendable, Identifiable {
    public static let emptyName: ModeName = "None"

    public let id: UInt8
    public let prompt: ModePrompt
    public let name: String
    public let editable: Bool
    public let configured: Bool
    public let favorite: Bool
    public let audio: AudioSettings?
    public let rawPayload: [UInt8]

    public init(id: UInt8, prompt: ModePrompt, name: String, editable: Bool, configured: Bool,
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
    public var prompt: ModePrompt
    public var name: ModeName
    public var audio: AudioSettings

    public init(slot: UInt8, prompt: ModePrompt, name: ModeName, audio: AudioSettings) {
        self.slot = slot
        self.prompt = prompt
        self.name = name
        self.audio = audio
    }
}
