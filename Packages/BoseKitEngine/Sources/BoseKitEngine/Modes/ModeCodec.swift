public protocol ModeCodec: Sendable {
    var statusLength: Int { get }
    func decodeStatus(_ payload: [UInt8]) throws -> ModeConfiguration
    func encodeWrite(_ draft: ModeDraft) throws -> [UInt8]
}

public struct StandardModeCodec: ModeCodec {
    public enum Layout: Int, Sendable { case status44 = 44, status47 = 47, status48 = 48 }

    private static let nameFieldLength = ModeName.maximumByteCount + 1
    private static let status44UnknownTailLength = 6
    private static let statusUnknownAfterNameLength = 4
    private static let statusUnknownBeforeWindBlockLength = 1

    public let layout: Layout

    public init(_ layout: Layout) { self.layout = layout }

    public var statusLength: Int { layout.rawValue }

    public func decodeStatus(_ payload: [UInt8]) throws -> ModeConfiguration {
        try PayloadReader.parse(payload, end: .exact) { reader in
            let id = try reader.u8()
            let prompt = ModePrompt(rawValue: try reader.u16())
            let editable = try reader.bool()
            let configured = try reader.bool()
            let favorite = try reader.bool()
            let name = try reader.nulTerminatedString(fieldLength: Self.nameFieldLength)
            let audio: AudioSettings?
            switch layout {
            case .status44:
                try reader.skip(Self.status44UnknownTailLength)
                audio = nil
            case .status47, .status48:
                try reader.skip(Self.statusUnknownAfterNameLength)
                let cnc = try CNCLevel(decoding: reader.u8())
                let automaticCNC = try reader.bool()
                let spatial = try SpatialAudio(decoding: reader.u8())
                try reader.skip(Self.statusUnknownBeforeWindBlockLength)
                let windBlock = try reader.bool()
                let ancEnabled = layout == .status48 ? try reader.bool() : nil
                audio = AudioSettings(cnc: cnc, automaticCNC: automaticCNC, spatial: spatial,
                                      windBlock: windBlock, ancEnabled: ancEnabled)
            }
            return ModeConfiguration(id: id, prompt: prompt, name: name, editable: editable, configured: configured,
                                     favorite: favorite, audio: audio, rawPayload: payload)
        }
    }

    public func encodeWrite(_ draft: ModeDraft) throws -> [UInt8] {
        let ancEnabled: Bool?
        switch layout {
        case .status44:
            throw BoseError.unsupported(.modeWritesInStatus44Layout)
        case .status47:
            guard draft.audio.ancEnabled == nil else { throw BoseError.unsupported(.ancToggleInStatus47Layout) }
            ancEnabled = nil
        case .status48:
            guard let enabled = draft.audio.ancEnabled else {
                throw BoseError.invalidArgument("48-byte mode layout requires ANC state")
            }
            ancEnabled = enabled
        }
        return PayloadWriter.build { writer in
            writer.u8(draft.slot)
            writer.u16(draft.prompt.rawValue)
            writer.nulPadded(Array(draft.name.rawValue.utf8), fieldLength: Self.nameFieldLength)
            writer.u8(draft.audio.cnc.rawValue)
            writer.bool(draft.audio.automaticCNC)
            writer.u8(draft.audio.spatial.rawValue)
            writer.bool(draft.audio.windBlock)
            if let ancEnabled { writer.bool(ancEnabled) }
        }
    }
}
