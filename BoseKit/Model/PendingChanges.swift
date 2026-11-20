import Observation
import BoseKitEngine

@MainActor @Observable
final class PendingChanges {
    struct Ticket {
        let settle: @MainActor () -> Void
    }

    var currentMode = PendingValue<UInt8>()
    var defaultMode = PendingValue<UInt8>()
    var favorites = PendingTable<UInt8, Bool>()
    var cnc = PendingValue<CNCLevel>()
    var spatialAudio = PendingValue<SpatialAudio>()
    var windBlock = PendingValue<Bool>()
    var ancEnabled = PendingValue<Bool>()
    var automaticCNC = PendingValue<Bool>()
    var anr = PendingValue<ANRLevel>()
    var equalizer = PendingTable<UInt8, Int8>()
    var multipoint = PendingValue<Bool>()
    var autoPause = PendingValue<Bool>()
    var autoAnswer = PendingValue<Bool>()
    var sidetone = PendingValue<SidetoneLevel>()
    var voicePromptsEnabled = PendingValue<Bool>()
    var voicePromptLanguage = PendingValue<VoicePromptLanguage>()
    var shortcut = PendingValue<ButtonAction>()

    var isEmpty: Bool {
        ![currentMode.isPending, defaultMode.isPending, favorites.isPending, cnc.isPending, spatialAudio.isPending,
          windBlock.isPending, ancEnabled.isPending, automaticCNC.isPending, anr.isPending, equalizer.isPending,
          multipoint.isPending, autoPause.isPending, autoAnswer.isPending, sidetone.isPending,
          voicePromptsEnabled.isPending, voicePromptLanguage.isPending, shortcut.isPending].contains(true)
    }

    func request<Value>(_ value: Value,
                        at field: ReferenceWritableKeyPath<PendingChanges, PendingValue<Value>>) -> Ticket {
        let request = self[keyPath: field].request(value)
        return Ticket { self[keyPath: field].settle(request) }
    }

    func clear() {
        currentMode.clear()
        defaultMode.clear()
        favorites.clear()
        cnc.clear()
        spatialAudio.clear()
        windBlock.clear()
        ancEnabled.clear()
        automaticCNC.clear()
        anr.clear()
        equalizer.clear()
        multipoint.clear()
        autoPause.clear()
        autoAnswer.clear()
        sidetone.clear()
        voicePromptsEnabled.clear()
        voicePromptLanguage.clear()
        shortcut.clear()
    }
}
