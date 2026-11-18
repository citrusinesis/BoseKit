import Foundation

public enum BoseFeatures {
    public static let battery = BoseFeature<BatteryStatus, Never>(
        id: .battery, address: .battery,
        decode: { bytes, profile in
            try require(bytes, count: 1)
            switch profile.batteryLayout {
            case .percentage:
                return BatteryStatus(percentage: bytes[0] <= 100 ? bytes[0] : nil, components: [:])
            case .components(let aggregate, let fallback):
                guard bytes.count.isMultiple(of: 4) else { throw BoseError.invalidPayload("Battery records") }
                var values: [BatteryComponent: UInt8] = [:]
                var seen: Set<BatteryComponent> = []
                for offset in stride(from: 0, to: bytes.count, by: 4) {
                    let component = BatteryComponent(rawValue: bytes[offset + 3])
                    guard seen.insert(component).inserted else {
                        throw BoseError.invalidPayload("Duplicate battery component")
                    }
                    if bytes[offset] <= 100 { values[component] = bytes[offset] }
                }
                let percent = values[aggregate] ?? fallback.compactMap { values[$0] }.min()
                return BatteryStatus(percentage: percent, components: values)
            }
        }
    )

    public static let name = BoseFeature<String, String>(id: .name, address: .name, decode: { bytes, _ in
        try require(bytes, count: 1)
        guard let value = String(bytes: bytes.dropFirst(), encoding: .utf8) else {
            throw BoseError.invalidPayload("Invalid text")
        }
        return value
    }, encode: { value, _ in
        let bytes = Array(value.utf8)
        guard !bytes.isEmpty, bytes.count <= maximumNameLength, !bytes.contains(0) else {
            throw BoseError.invalidArgument("Device name must be 1...\(maximumNameLength) UTF-8 bytes without NUL")
        }
        return bytes
    })

    public static let maximumNameLength = 31

    private static func readOnlyText(_ id: FeatureID, _ address: BMAPAddress) -> BoseFeature<String, Never> {
        BoseFeature(id: id, address: address, decode: { bytes, _ in
            guard let value = String(bytes: bytes, encoding: .ascii) else {
                throw BoseError.invalidPayload("Invalid ASCII text")
            }
            return value
        })
    }

    public static let firmware = readOnlyText(.firmware, .firmware)
    public static let serial = readOnlyText(.serial, .serial)
    public static let model = readOnlyText(.model, .model)

    public static let cnc = BoseFeature<CNCStatus, UInt8>(id: .cnc, address: .cnc, decode: { bytes, _ in
        try require(bytes, count: 3)
        guard bytes[0] > 0, bytes[1] < bytes[0] else { throw BoseError.invalidPayload("Invalid CNC range") }
        return CNCStatus(current: bytes[1], maximum: bytes[0] - 1)
    }, encode: { value, _ in
        guard value <= 10 else { throw BoseError.invalidArgument("CNC must be 0...10") }
        return [value, 1]
    })

    public static let anr = BoseFeature<ANRLevel, ANRLevel>(id: .anr, address: .anr, decode: { bytes, _ in
        try require(bytes, count: 1)
        guard let level = ANRLevel(rawValue: bytes[0]) else { throw BoseError.invalidPayload("Unknown ANR level") }
        return level
    }, encode: { value, _ in [value.rawValue] })

    public static let equalizer = BoseFeature<[EQBand], EQAdjustment>(id: .equalizer, address: .equalizer,
        decode: { bytes, _ in
            guard !bytes.isEmpty, bytes.count.isMultiple(of: 4) else { throw BoseError.invalidPayload("EQ records") }
            var bands: [EQBand] = []
            for offset in stride(from: 0, to: bytes.count, by: 4) {
                let minimum = Int8(bitPattern: bytes[offset])
                let maximum = Int8(bitPattern: bytes[offset + 1])
                let value = Int8(bitPattern: bytes[offset + 2])
                let id = bytes[offset + 3]
                guard minimum <= maximum, (minimum...maximum).contains(value),
                      !bands.contains(where: { $0.id == id }) else { throw BoseError.invalidPayload("Invalid EQ band") }
                bands.append(EQBand(id: id, range: minimum...maximum, value: value))
            }
            return bands
        }, encode: { adjustment, _ in
            guard adjustment.band <= 2, (-10...10).contains(adjustment.value) else {
                throw BoseError.invalidArgument("EQ band/value out of range")
            }
            return [UInt8(bitPattern: adjustment.value), adjustment.band]
        })

    private static func toggle(_ id: FeatureID, _ address: BMAPAddress, mask: UInt8 = 0xff,
                               operation: BMAPOperator = .setGet) -> BoseFeature<Bool, Bool> {
        BoseFeature(id: id, address: address, writeOperation: operation, decode: { bytes, _ in
            try require(bytes, count: 1)
            return bytes[0] & mask != 0
        }, encode: { value, _ in [value ? 1 : 0] })
    }

    public static let multipoint = toggle(.multipoint, .multipoint, mask: 1)
    public static let autoPause = toggle(.autoPause, .autoPause)
    public static let autoAnswer = toggle(.autoAnswer, .autoAnswer)
    public static let pairing = toggle(.pairing, .pairing, operation: .start)

    public static let sidetone = BoseFeature<SidetoneLevel, SidetoneLevel>(
        id: .sidetone, address: .sidetone, decode: { bytes, _ in
            try require(bytes, count: 2)
            guard let level = SidetoneLevel(rawValue: bytes[1]) else { throw BoseError.invalidPayload("Unknown sidetone") }
            return level
        }, encode: { value, _ in [1, value.rawValue] })

    public static let voicePrompts = BoseFeature<VoicePrompts, VoicePrompts>(
        id: .voicePrompts, address: .voicePrompts, decode: { bytes, _ in
            try require(bytes, count: 1)
            return VoicePrompts(enabled: bytes[0] & 0x20 != 0,
                                language: VoicePromptLanguage(rawValue: bytes[0] & 0x1f), rawPayload: bytes)
        }, encode: { value, _ in
            try require(value.rawPayload, count: 1)
            guard value.language.rawValue < 32 else { throw BoseError.invalidArgument("Voice language") }
            return [(value.rawPayload[0] & 0xc0) | (value.enabled ? 0x20 : 0) | value.language.rawValue]
        })

    public static let buttons = BoseFeature<ButtonConfiguration, ButtonAssignment>(
        id: .buttons, address: .buttons, decode: { bytes, profile in
            try require(bytes, count: 3)
            let bitmap = Array(bytes.dropFirst(3).prefix(4))
            let mask: UInt32
            if profile.buttonBitmapBigEndian {
                mask = bitmap.reduce(0) { ($0 << 8) | UInt32($1) }
            } else {
                mask = bitmap.enumerated().reduce(0) { $0 | UInt32($1.element) << ($1.offset * 8) }
            }
            let assignment = ButtonAssignment(button: bytes[0], event: ButtonEvent(rawValue: bytes[1]),
                                              action: ButtonAction(rawValue: bytes[2]))
            let supported = (0..<32).compactMap { mask & (1 << $0) != 0 ? ButtonAction(rawValue: UInt8($0)) : nil }
            return ButtonConfiguration(assignment: assignment, supportedActions: Set(supported))
        }, encode: { value, _ in [value.button, value.event.rawValue, value.action.rawValue] })

    public static let source = BoseFeature<AudioSource, Never>(id: .source, address: .source,
        decode: { bytes, _ in
            try require(bytes, count: 3)
            let kind = AudioSourceKind(rawValue: bytes[2])
            guard kind == .bluetooth else { return AudioSource(kind: kind, bluetoothAddress: nil) }
            try require(bytes, count: 9)
            return AudioSource(kind: kind, bluetoothAddress: BluetoothAddress(bytes: Array(bytes[3..<9])))
        })

    public static let favorites = BoseFeature<FavoriteModes, FavoriteModes>(id: .favorites, address: .favorites,
        decode: { bytes, _ in
            try require(bytes, count: 3)
            guard bytes[0] <= 16 else { throw BoseError.invalidPayload("Favorite slot count") }
            let mask = UInt16(bytes[1]) << 8 | UInt16(bytes[2])
            return FavoriteModes(slotCount: bytes[0],
                slots: Set((0..<bytes[0]).filter { mask & (1 << $0) != 0 }))
        }, encode: { value, _ in
            guard value.slotCount <= 16, value.slots.allSatisfy({ $0 < value.slotCount }) else {
                throw BoseError.invalidArgument("Favorite slots out of range")
            }
            let mask = value.slots.reduce(UInt16(0)) { $0 | (1 << $1) }
            return [value.slotCount, UInt8(mask >> 8), UInt8(mask & 0xff)]
        })

    public static let defaultMode = BoseFeature<UInt8, UInt8>(
        id: .defaultMode, address: .defaultMode, decode: { bytes, _ in
            try require(bytes, count: 1)
            return bytes[0]
        }, encode: { slot, profile in
            if let expected = profile.modePolicy?.expectedSlots, !expected.contains(slot) {
                throw BoseError.invalidArgument("Default mode slot")
            }
            return [slot]
        })

    public static let power = BoseFeature<UInt8, Never>(
        id: .power, address: .power, decode: { bytes, _ in
            try require(bytes, count: 1)
            return bytes[0]
        })

    public static let audioSettings = BoseFeature<AudioSettings, AudioSettings>(
        id: .audioSettings, address: .audioSettings, decode: { bytes, _ in
            try require(bytes, count: 5)
            guard bytes[0] <= 10, let spatial = SpatialAudio(rawValue: bytes[2]) else {
                throw BoseError.invalidPayload("Audio settings")
            }
            return AudioSettings(cnc: bytes[0], automaticCNC: bytes[1] != 0,
                                 spatial: spatial, windBlock: bytes[3] != 0, ancEnabled: bytes[4] != 0)
        }, encode: { value, _ in
            guard value.cnc <= 10, let anc = value.ancEnabled else { throw BoseError.invalidArgument("Audio settings") }
            return [value.cnc, value.automaticCNC ? 1 : 0, value.spatial.rawValue, value.windBlock ? 1 : 0, anc ? 1 : 0]
        })
}
