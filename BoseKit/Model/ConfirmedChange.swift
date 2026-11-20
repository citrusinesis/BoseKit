import BoseKitEngine

enum ConfirmedChange {
    case name(String)
    case anr(ANRLevel)
    case equalizer([EQBand])
    case audio(AudioSettings)
    case mode(ModeConfiguration)
    case favorites(FavoriteModes)
    case defaultMode(UInt8)
    case multipoint(Bool)
    case autoPause(Bool)
    case autoAnswer(Bool)
    case pairing(Bool)
    case sidetone(SidetoneLevel)
    case voicePrompts(VoicePrompts)
    case buttons(ButtonConfiguration)
}
