public struct VoicePromptLanguage: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let englishUK = Self(rawValue: 0)
    public static let englishUS = Self(rawValue: 1)
    public static let french = Self(rawValue: 2)
    public static let italian = Self(rawValue: 3)
    public static let german = Self(rawValue: 4)
    public static let spanish = Self(rawValue: 5)
    public static let spanishMexico = Self(rawValue: 6)
    public static let portuguese = Self(rawValue: 7)
    public static let mandarin = Self(rawValue: 8)
    public static let korean = Self(rawValue: 9)
    public static let russian = Self(rawValue: 10)
    public static let polish = Self(rawValue: 11)
    public static let hebrew = Self(rawValue: 12)
    public static let turkish = Self(rawValue: 13)
    public static let dutch = Self(rawValue: 14)
    public static let japanese = Self(rawValue: 15)
    public static let cantonese = Self(rawValue: 16)
    public static let arabic = Self(rawValue: 17)
    public static let swedish = Self(rawValue: 18)
    public static let danish = Self(rawValue: 19)
    public static let norwegian = Self(rawValue: 20)
    public static let finnish = Self(rawValue: 21)
    public static let hindi = Self(rawValue: 22)

    public static let known: [Self] = (0...22).map(Self.init(rawValue:))
}

public struct VoicePrompts: Equatable, Sendable {
    public var enabled: Bool
    public var language: VoicePromptLanguage
    public let rawPayload: [UInt8]
    public init(enabled: Bool, language: VoicePromptLanguage, rawPayload: [UInt8]) {
        self.enabled = enabled
        self.language = language
        self.rawPayload = rawPayload
    }
}
