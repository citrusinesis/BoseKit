public struct FeatureID: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }

    public static let battery = Self(rawValue: "battery")
    public static let firmware = Self(rawValue: "firmware")
    public static let serial = Self(rawValue: "serial")
    public static let model = Self(rawValue: "model")
    public static let name = Self(rawValue: "name")
    public static let voicePrompts = Self(rawValue: "voicePrompts")
    public static let cnc = Self(rawValue: "cnc")
    public static let anr = Self(rawValue: "anr")
    public static let equalizer = Self(rawValue: "equalizer")
    public static let buttons = Self(rawValue: "buttons")
    public static let multipoint = Self(rawValue: "multipoint")
    public static let sidetone = Self(rawValue: "sidetone")
    public static let autoPause = Self(rawValue: "autoPause")
    public static let autoAnswer = Self(rawValue: "autoAnswer")
    public static let pairing = Self(rawValue: "pairing")
    public static let routing = Self(rawValue: "routing")
    public static let source = Self(rawValue: "source")
    public static let sourceDevices = Self(rawValue: "sourceDevices")
    public static let power = Self(rawValue: "power")
    public static let modes = Self(rawValue: "modes")
    public static let currentMode = Self(rawValue: "currentMode")
    public static let defaultMode = Self(rawValue: "defaultMode")
    public static let favorites = Self(rawValue: "favorites")
    public static let audioSettings = Self(rawValue: "audioSettings")
    public static let spatialAudio = Self(rawValue: "spatialAudio")
    public static let windBlock = Self(rawValue: "windBlock")
    public static let ancToggle = Self(rawValue: "ancToggle")
}

public struct FeatureAccess: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let read = Self(rawValue: 1)
    public static let write = Self(rawValue: 2)
    public static let readWrite: Self = [.read, .write]
}
