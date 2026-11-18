public struct VoicePromptLanguage: RawRepresentable, Hashable, Sendable {
    static let mask: UInt8 = 0x1f

    public let rawValue: UInt8

    public init?(rawValue: UInt8) {
        guard rawValue & ~Self.mask == 0 else { return nil }
        self.rawValue = rawValue
    }

    init(bits: UInt8) {
        rawValue = bits & Self.mask
    }

    public static let englishUK = Self(bits: 0)
    public static let englishUS = Self(bits: 1)
    public static let french = Self(bits: 2)
    public static let italian = Self(bits: 3)
    public static let german = Self(bits: 4)
    public static let spanish = Self(bits: 5)
    public static let spanishMexico = Self(bits: 6)
    public static let portuguese = Self(bits: 7)
    public static let mandarin = Self(bits: 8)
    public static let korean = Self(bits: 9)
    public static let russian = Self(bits: 10)
    public static let polish = Self(bits: 11)
    public static let hebrew = Self(bits: 12)
    public static let turkish = Self(bits: 13)
    public static let dutch = Self(bits: 14)
    public static let japanese = Self(bits: 15)
    public static let cantonese = Self(bits: 16)
    public static let arabic = Self(bits: 17)
    public static let swedish = Self(bits: 18)
    public static let danish = Self(bits: 19)
    public static let norwegian = Self(bits: 20)
    public static let finnish = Self(bits: 21)
    public static let hindi = Self(bits: 22)

    public static let known: [Self] = [
        .englishUK,
        .englishUS,
        .french,
        .italian,
        .german,
        .spanish,
        .spanishMexico,
        .portuguese,
        .mandarin,
        .korean,
        .russian,
        .polish,
        .hebrew,
        .turkish,
        .dutch,
        .japanese,
        .cantonese,
        .arabic,
        .swedish,
        .danish,
        .norwegian,
        .finnish,
        .hindi,
    ]
}

public struct VoicePrompts: Equatable, Sendable {
    private static let enabledBit: UInt8 = 0x20
    private static let preservedMask: UInt8 = 0xc0

    public var enabled: Bool
    public var language: VoicePromptLanguage
    let preservedBits: UInt8

    init(enabled: Bool, language: VoicePromptLanguage, preservedBits: UInt8) {
        self.enabled = enabled
        self.language = language
        self.preservedBits = preservedBits & Self.preservedMask
    }

    init(flags: UInt8) {
        self.init(enabled: flags & Self.enabledBit != 0, language: VoicePromptLanguage(bits: flags),
                  preservedBits: flags)
    }

    var flags: UInt8 {
        preservedBits | (enabled ? Self.enabledBit : 0) | language.rawValue
    }
}
