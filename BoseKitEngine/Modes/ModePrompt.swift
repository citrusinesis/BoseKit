public struct ModePrompt: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) { self.rawValue = rawValue }

    public static let none = Self(rawValue: 0)
    public static let quiet = Self(rawValue: 1)
    public static let aware = Self(rawValue: 2)
    public static let transparent = Self(rawValue: 3)
    public static let transparency = Self(rawValue: 4)
    public static let masking = Self(rawValue: 5)
    public static let comfort = Self(rawValue: 6)
    public static let commute = Self(rawValue: 7)
    public static let outdoor = Self(rawValue: 8)
    public static let workout = Self(rawValue: 9)
    public static let home = Self(rawValue: 10)
    public static let work = Self(rawValue: 11)
    public static let music = Self(rawValue: 12)
    public static let focus = Self(rawValue: 13)
    public static let relax = Self(rawValue: 14)
    public static let flight = Self(rawValue: 15)
    public static let airport = Self(rawValue: 16)
    public static let driving = Self(rawValue: 17)
    public static let training = Self(rawValue: 18)
    public static let gym = Self(rawValue: 19)
    public static let run = Self(rawValue: 20)
    public static let walk = Self(rawValue: 21)
    public static let hike = Self(rawValue: 22)
    public static let talk = Self(rawValue: 23)
    public static let call = Self(rawValue: 24)
    public static let whisper = Self(rawValue: 25)
    public static let hearing = Self(rawValue: 26)
    public static let learn = Self(rawValue: 27)
    public static let podcast = Self(rawValue: 28)
    public static let audiobook = Self(rawValue: 29)
    public static let calm = Self(rawValue: 30)
    public static let sleep = Self(rawValue: 31)
    public static let meditate = Self(rawValue: 32)
    public static let yoga = Self(rawValue: 33)
    public static let immersion = Self(rawValue: 34)
    public static let stereo = Self(rawValue: 35)
    public static let cinema = Self(rawValue: 36)

    public static let named: [Self] = (1...36).map(Self.init(rawValue:))

    public var protocolName: String? {
        let names = ["NONE", "QUIET", "AWARE", "TRANSPARENT", "TRANSPARENCY", "MASKING", "COMFORT", "COMMUTE", "OUTDOOR", "WORKOUT", "HOME", "WORK", "MUSIC", "FOCUS", "RELAX", "FLIGHT", "AIRPORT", "DRIVING", "TRAINING", "GYM", "RUN", "WALK", "HIKE", "TALK", "CALL", "WHISPER", "HEARING", "LEARN", "PODCAST", "AUDIOBOOK", "CALM", "SLEEP", "MEDITATE", "YOGA", "IMMERSION", "STEREO", "CINEMA"]
        guard Int(rawValue) < names.count else { return nil }
        return names[Int(rawValue)]
    }
}

extension ModeConfiguration {
    public var voicePrompt: ModePrompt { ModePrompt(rawValue: prompt) }
}

extension ModeDraft {
    public init(slot: UInt8, voicePrompt: ModePrompt, name: String, audio: AudioSettings) {
        self.init(slot: slot, prompt: voicePrompt.rawValue, name: name, audio: audio)
    }
}
