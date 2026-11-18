import BoseKitEngine

enum RefreshScope {
    case probe
    case live
    case full
}

struct DeviceSnapshot {
    var battery: BatteryStatus?

    var currentMode: UInt8?
    var cnc: CNCStatus?
    var anr: ANRLevel?
    var equalizer: [EQBand] = []
    var audio: AudioSettings?

    var name: String?
    var firmware: String?
    var serial: String?
    var modelName: String?
    var modes: [ModeConfiguration] = []
    var defaultMode: UInt8?
    var favorites: FavoriteModes?
    var multipoint: Bool?
    var autoPause: Bool?
    var autoAnswer: Bool?
    var pairing: Bool?
    var sidetone: SidetoneLevel?
    var voicePrompts: VoicePrompts?
    var buttons: ButtonConfiguration?
    var source: AudioSource?
    var sourceDevices: [SourceDevice] = []
}
