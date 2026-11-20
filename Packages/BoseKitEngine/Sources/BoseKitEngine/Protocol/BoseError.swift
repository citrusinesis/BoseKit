public enum BoseError: Error, Equatable, Sendable {
    case invalidPayload(String)
    case invalidArgument(String)
    case invalidState(InvalidState)
    case unsupported(Unsupported)
    case device(BMAPAddress, code: BMAPErrorCode?, detail: UInt8?)
    case disconnected
    case timeout
    case transport(Int32)
    case verificationFailed(VerificationFailure)
    case duplicateProduct(UInt16)
    case duplicateProfile(String)

    public enum Unsupported: Equatable, Sendable {
        case feature(FeatureID)
        case modePolicy
        case nonEditableModeSlot(UInt8)
        case automaticCNCInCustomModes
        case continuousNoiseControl
        case audioSettings
        case modeWritesInStatus44Layout
        case ancToggleInStatus47Layout
        case voicePromptLanguageNotInstalled(VoicePromptLanguage)
    }

    public enum InvalidState: Equatable, Sendable {
        case windBlockLocksCNC
        case modeNotConfigured
        case noFallbackPreset
        case currentModeUnavailable
        case currentModeHasNoAudioSettings
        case modeNameNotWritable
    }

    public enum VerificationFailure: Equatable, Sendable {
        case feature(FeatureID)
        case modeMissingAfterWrite
        case modeFieldsDiffer
        case deletedModeStillConfigured
        case modeNotConfigured
        case currentModeNotApplied
    }
}
