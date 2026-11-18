import Foundation

public protocol ModeCodec: Sendable {
    var statusLength: Int { get }
    func decodeStatus(_ payload: [UInt8]) throws -> ModeConfiguration
    func encodeWrite(_ draft: ModeDraft) throws -> [UInt8]
}

public struct StandardModeCodec: ModeCodec {
    public enum Layout: Int, Sendable { case status44 = 44, status47 = 47, status48 = 48 }
    public let layout: Layout

    public init(_ layout: Layout) { self.layout = layout }

    public var statusLength: Int { layout.rawValue }

    public func decodeStatus(_ payload: [UInt8]) throws -> ModeConfiguration {
        guard payload.count == layout.rawValue else {
            throw BoseError.invalidPayload("Mode STATUS must contain \(layout.rawValue) bytes")
        }
        let nameBytes = payload[6..<38].prefix { $0 != 0 }
        guard let name = String(bytes: nameBytes, encoding: .utf8) else {
            throw BoseError.invalidPayload("Invalid UTF-8 mode name")
        }
        let audio: AudioSettings?
        if layout == .status44 {
            audio = nil
        } else {
            guard payload[42] <= 10, let spatial = SpatialAudio(rawValue: payload[44]) else {
                throw BoseError.invalidPayload("Unknown mode audio settings")
            }
            audio = AudioSettings(cnc: payload[42], automaticCNC: payload[43] != 0,
                spatial: spatial, windBlock: payload[46] != 0,
                ancEnabled: layout == .status48 ? payload[47] != 0 : nil)
        }
        return ModeConfiguration(id: payload[0], prompt: UInt16(payload[1]) << 8 | UInt16(payload[2]),
            name: name, editable: payload[3] != 0, configured: payload[4] != 0,
            favorite: payload[5] != 0, audio: audio, rawPayload: payload)
    }

    public func encodeWrite(_ draft: ModeDraft) throws -> [UInt8] {
        guard layout != .status44 else { throw BoseError.unsupported("44-byte mode writes") }
        guard draft.audio.cnc <= 10 else { throw BoseError.invalidArgument("CNC must be 0...10") }
        let name = Array(draft.name.utf8)
        guard name.count <= 31, !name.contains(0) else {
            throw BoseError.invalidArgument("Mode name must fit 31 UTF-8 bytes without NUL")
        }
        var bytes = [draft.slot, UInt8(draft.prompt >> 8), UInt8(draft.prompt & 0xff)]
        bytes += name + Array(repeating: 0, count: 32 - name.count)
        bytes += [draft.audio.cnc, draft.audio.automaticCNC ? 1 : 0,
                  draft.audio.spatial.rawValue, draft.audio.windBlock ? 1 : 0]
        if layout == .status48 {
            guard let enabled = draft.audio.ancEnabled else {
                throw BoseError.invalidArgument("48-byte mode layout requires ANC state")
            }
            bytes.append(enabled ? 1 : 0)
        } else if draft.audio.ancEnabled != nil {
            throw BoseError.unsupported("ANC toggle in 47-byte layout")
        }
        return bytes
    }
}
