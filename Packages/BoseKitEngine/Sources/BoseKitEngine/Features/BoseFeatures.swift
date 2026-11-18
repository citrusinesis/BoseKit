public enum BoseFeatures {
    private static let maximumBatteryPercentage: UInt8 = 100
    private static let batteryRecordUnknownLength = 2
    private static let nameUnknownPrefixLength = 1
    private static let cncStatusUnknownLength = 1
    private static let cncWriteFlag: UInt8 = 1
    private static let multipointEnabledBit: UInt8 = 0x01
    private static let sidetoneUnknownPrefixLength = 1
    private static let sidetoneWriteFlag: UInt8 = 1
    private static let sourceUnknownPrefixLength = 2

    public static let battery = BoseFeature<BatteryStatus, Never>(
        id: .battery, address: .battery,
        decode: { bytes, profile in
            switch profile.batteryLayout {
            case .percentage:
                return try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { reader in
                    BatteryStatus(percentage: batteryPercentage(try reader.u8()), components: [:])
                }
            case .components(let aggregate, let fallback):
                guard !bytes.isEmpty else { throw BoseError.invalidPayload("Battery records") }
                let values = try PayloadReader.parse(bytes, end: .exact) { reader in
                    var values: [BatteryComponent: UInt8] = [:]
                    var seen: Set<BatteryComponent> = []
                    while !reader.isAtEnd {
                        let level = try reader.u8()
                        try reader.skip(batteryRecordUnknownLength)
                        let component = BatteryComponent(rawValue: try reader.u8())
                        guard seen.insert(component).inserted else {
                            throw BoseError.invalidPayload("Duplicate battery component")
                        }
                        values[component] = batteryPercentage(level)
                    }
                    return values
                }
                let percent = values[aggregate] ?? fallback.compactMap { values[$0] }.min()
                return BatteryStatus(percentage: percent, components: values)
            }
        }
    )

    private static func batteryPercentage(_ level: UInt8) -> UInt8? {
        level <= maximumBatteryPercentage ? level : nil
    }

    public static let name = BoseFeature<String, DeviceName>(id: .name, address: .name, decode: { bytes, _ in
        try PayloadReader.parse(bytes, end: .exact) { reader in
            try reader.skip(nameUnknownPrefixLength)
            return try reader.remainingString(.utf8)
        }
    }, encode: { value, _ in
        Array(value.rawValue.utf8)
    }, confirm: { $0 == $1.rawValue })

    private static func readOnlyText(_ id: FeatureID, _ address: BMAPAddress) -> BoseFeature<String, Never> {
        BoseFeature(id: id, address: address, decode: { bytes, _ in
            try PayloadReader.parse(bytes, end: .exact) { try $0.remainingString(.ascii) }
        })
    }

    public static let firmware = readOnlyText(.firmware, .firmware)
    public static let serial = readOnlyText(.serial, .serial)
    public static let model = readOnlyText(.model, .model)

    public static let cnc = BoseFeature<CNCStatus, CNCLevel>(id: .cnc, address: .cnc, decode: { bytes, _ in
        try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { reader in
            let stepCount = try reader.u8()
            let current = try reader.u8()
            try reader.skip(cncStatusUnknownLength)
            guard stepCount > 0, current < stepCount else { throw BoseError.invalidPayload("Invalid CNC range") }
            return CNCStatus(current: current, maximum: stepCount - 1)
        }
    }, encode: { level, _ in
        PayloadWriter.build { writer in
            writer.u8(level.rawValue)
            writer.u8(cncWriteFlag)
        }
    }, confirm: { status, level in status.current == level.rawValue })

    public static let anr = BoseFeature<ANRLevel, ANRLevel>(id: .anr, address: .anr, decode: { bytes, _ in
        try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { reader in
            guard let level = ANRLevel(rawValue: try reader.u8()) else {
                throw BoseError.invalidPayload("Unknown ANR level")
            }
            return level
        }
    }, encode: { value, _ in [value.rawValue] }, confirm: { $0 == $1 })

    public static let equalizer = BoseFeature<[EQBand], EQAdjustment>(id: .equalizer, address: .equalizer,
        decode: { bytes, _ in
            guard !bytes.isEmpty else { throw BoseError.invalidPayload("EQ records") }
            return try PayloadReader.parse(bytes, end: .exact) { reader in
                var bands: [EQBand] = []
                while !reader.isAtEnd {
                    let minimum = Int8(bitPattern: try reader.u8())
                    let maximum = Int8(bitPattern: try reader.u8())
                    let value = Int8(bitPattern: try reader.u8())
                    let id = try reader.u8()
                    guard minimum <= maximum, (minimum...maximum).contains(value),
                          !bands.contains(where: { $0.id == id }) else {
                        throw BoseError.invalidPayload("Invalid EQ band")
                    }
                    bands.append(EQBand(id: id, range: minimum...maximum, value: value))
                }
                return bands
            }
        }, encode: { adjustment, _ in
            PayloadWriter.build { writer in
                writer.u8(UInt8(bitPattern: adjustment.value))
                writer.u8(adjustment.band)
            }
        }, confirm: { bands, adjustment in
            bands.contains { $0.id == adjustment.band && $0.value == adjustment.value }
        })

    private static func toggle(_ id: FeatureID, _ address: BMAPAddress, mask: UInt8 = 0xff,
                               operation: BMAPOperator = .setGet) -> BoseFeature<Bool, Bool> {
        BoseFeature(id: id, address: address, writeOperation: operation, decode: { bytes, _ in
            try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { try $0.u8() & mask != 0 }
        }, encode: { value, _ in
            PayloadWriter.build { $0.bool(value) }
        }, confirm: { $0 == $1 })
    }

    public static let multipoint = toggle(.multipoint, .multipoint, mask: multipointEnabledBit)
    public static let autoPause = toggle(.autoPause, .autoPause)
    public static let autoAnswer = toggle(.autoAnswer, .autoAnswer)
    public static let pairing = toggle(.pairing, .pairing, operation: .start)

    public static let sidetone = BoseFeature<SidetoneLevel, SidetoneLevel>(
        id: .sidetone, address: .sidetone, decode: { bytes, _ in
            try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { reader in
                try reader.skip(sidetoneUnknownPrefixLength)
                guard let level = SidetoneLevel(rawValue: try reader.u8()) else {
                    throw BoseError.invalidPayload("Unknown sidetone")
                }
                return level
            }
        }, encode: { value, _ in
            PayloadWriter.build { writer in
                writer.u8(sidetoneWriteFlag)
                writer.u8(value.rawValue)
            }
        }, confirm: { $0 == $1 })

    public static let voicePrompts = BoseFeature<VoicePrompts, VoicePrompts>(
        id: .voicePrompts, address: .voicePrompts, decode: { bytes, _ in
            try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { VoicePrompts(flags: try $0.u8()) }
        }, encode: { value, _ in [value.flags] },
        confirm: { $0.enabled == $1.enabled && $0.language == $1.language })

    public static let buttons = BoseFeature<ButtonConfiguration, ButtonAssignment>(
        id: .buttons, address: .buttons, decode: { bytes, _ in
            try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { reader in
                let assignment = ButtonAssignment(button: try reader.u8(), event: ButtonEvent(rawValue: try reader.u8()),
                                                  action: ButtonAction(rawValue: try reader.u8()))
                let bitmap: UInt32 = reader.isAtEnd ? 0 : try reader.u32()
                let supported = (0..<UInt32.bitWidth).compactMap {
                    bitmap & (1 << $0) != 0 ? ButtonAction(rawValue: UInt8($0)) : nil
                }
                return ButtonConfiguration(assignment: assignment, supportedActions: Set(supported))
            }
        }, encode: { value, _ in
            PayloadWriter.build { writer in
                writer.u8(value.button)
                writer.u8(value.event.rawValue)
                writer.u8(value.action.rawValue)
            }
        }, confirm: { $0.assignment == $1 })

    public static let source = BoseFeature<AudioSource, Never>(id: .source, address: .source,
        decode: { bytes, _ in
            try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { reader in
                try reader.skip(sourceUnknownPrefixLength)
                let kind = AudioSourceKind(rawValue: try reader.u8())
                guard kind == .bluetooth else { return AudioSource(kind: kind, bluetoothAddress: nil) }
                let address = try reader.bluetoothAddress()
                try reader.requireEnd()
                return AudioSource(kind: kind, bluetoothAddress: address)
            }
        })

    public static let favorites = BoseFeature<FavoriteModes, FavoriteModes>(id: .favorites, address: .favorites,
        decode: { bytes, _ in
            try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { reader in
                let slotCount = try reader.u8()
                let mask = try reader.u16()
                guard slotCount <= FavoriteModes.maximumSlotCount else {
                    throw BoseError.invalidPayload("Favorite slot count")
                }
                return try FavoriteModes(slotCount: slotCount,
                                         slots: Set((0..<slotCount).filter { mask & (1 << $0) != 0 }))
            }
        }, encode: { value, _ in
            PayloadWriter.build { writer in
                writer.u8(value.slotCount)
                writer.u16(value.slots.reduce(0) { $0 | (1 << $1) })
            }
        }, confirm: { $0.slots == $1.slots })

    public static let defaultMode = BoseFeature<UInt8, UInt8>(
        id: .defaultMode, address: .defaultMode, decode: { bytes, _ in
            try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { try $0.u8() }
        }, encode: { slot, profile in
            if let expected = profile.modePolicy?.expectedSlots, !expected.contains(slot) {
                throw BoseError.invalidArgument("Default mode slot")
            }
            return [slot]
        }, confirm: { $0 == $1 })

    public static let audioSettings = BoseFeature<AudioSettings, AudioSettings>(
        id: .audioSettings, address: .audioSettings, decode: { bytes, _ in
            try PayloadReader.parse(bytes, end: .trailingBytesAllowed) { reader in
                let cnc = try reader.u8()
                let automaticCNC = try reader.bool()
                let spatial = try reader.u8()
                let windBlock = try reader.bool()
                let ancEnabled = try reader.bool()
                return AudioSettings(cnc: try CNCLevel(decoding: cnc), automaticCNC: automaticCNC,
                                     spatial: try SpatialAudio(decoding: spatial), windBlock: windBlock,
                                     ancEnabled: ancEnabled)
            }
        }, encode: { value, _ in
            guard let ancEnabled = value.ancEnabled else {
                throw BoseError.invalidArgument("Audio settings require ANC state")
            }
            return PayloadWriter.build { writer in
                writer.u8(value.cnc.rawValue)
                writer.bool(value.automaticCNC)
                writer.u8(value.spatial.rawValue)
                writer.bool(value.windBlock)
                writer.bool(ancEnabled)
            }
        }, confirm: { $0 == $1 })
}
