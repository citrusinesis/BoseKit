public struct ButtonEvent: RawRepresentable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let longPress = Self(rawValue: 0x09)
}

public struct ButtonAction: RawRepresentable, Hashable, Sendable, Comparable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let voiceAssistant = Self(rawValue: 1)
    public static let noiseControl = Self(rawValue: 2)
    public static let batteryLevel = Self(rawValue: 3)
    public static let playPause = Self(rawValue: 4)
    public static let increaseAmbient = Self(rawValue: 5)
    public static let decreaseAmbient = Self(rawValue: 6)
    public static let wakeWord = Self(rawValue: 7)
    public static let switchDevice = Self(rawValue: 8)
    public static let conversationMode = Self(rawValue: 9)
    public static let nextTrack = Self(rawValue: 10)
    public static let previousTrack = Self(rawValue: 11)
    public static let notifications = Self(rawValue: 12)
    public static let windBlock = Self(rawValue: 13)
    public static let disabled = Self(rawValue: 14)
    public static let appAction = Self(rawValue: 15)
    public static let spotify = Self(rawValue: 16)
    public static let cycleModes = Self(rawValue: 17)
    public static let immersiveAudio = Self(rawValue: 19)
    public static let wiredInput = Self(rawValue: 20)
    public static let linkDevices = Self(rawValue: 21)

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct ButtonAssignment: Equatable, Sendable {
    public let button: UInt8
    public let event: ButtonEvent
    public let action: ButtonAction
    public init(button: UInt8, event: ButtonEvent, action: ButtonAction) {
        self.button = button; self.event = event; self.action = action
    }
}

public struct ButtonConfiguration: Equatable, Sendable {
    public let assignment: ButtonAssignment
    public let supportedActions: Set<ButtonAction>

    public var selectableActions: [ButtonAction] {
        supportedActions.union([assignment.action]).sorted()
    }
}
