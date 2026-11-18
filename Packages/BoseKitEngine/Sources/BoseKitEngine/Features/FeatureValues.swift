public struct EQBand: Equatable, Sendable, Identifiable {
    public let id: UInt8
    public let range: ClosedRange<Int8>
    public let value: Int8
}

public struct EQAdjustment: Sendable {
    public let band: UInt8
    public let value: Int8
    public init(band: UInt8, value: Int8) { self.band = band; self.value = value }
}

public struct CNCStatus: Equatable, Sendable {
    public let current: UInt8
    public let maximum: UInt8
}

public enum ANRLevel: UInt8, Sendable, CaseIterable { case off = 0, high, wind, low }
public enum SidetoneLevel: UInt8, Sendable, CaseIterable { case off = 0, high, medium, low }

public struct AudioSourceKind: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let none = Self(rawValue: 0)
    public static let bluetooth = Self(rawValue: 1)
    public static let wired = Self(rawValue: 2)
}

public struct AudioSource: Equatable, Sendable {
    public let kind: AudioSourceKind
    public let bluetoothAddress: BluetoothAddress?
}

public struct FavoriteModes: Equatable, Sendable {
    public let slotCount: UInt8
    public let slots: Set<UInt8>
    public init(slotCount: UInt8, slots: Set<UInt8>) {
        self.slotCount = slotCount; self.slots = slots
    }
}
