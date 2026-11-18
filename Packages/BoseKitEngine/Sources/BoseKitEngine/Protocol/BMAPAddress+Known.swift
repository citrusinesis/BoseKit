extension BMAPAddress {
    public static let productInfo = BMAPAddress(0, 1)
    public static let firmware = BMAPAddress(0, 5)
    public static let serial = BMAPAddress(0, 7)
    public static let model = BMAPAddress(0, 15)

    public static let name = BMAPAddress(1, 2)
    public static let voicePrompts = BMAPAddress(1, 3)
    public static let cnc = BMAPAddress(1, 5)
    public static let anr = BMAPAddress(1, 6)
    public static let equalizer = BMAPAddress(1, 7)
    public static let buttons = BMAPAddress(1, 9)
    public static let multipoint = BMAPAddress(1, 10)
    public static let sidetone = BMAPAddress(1, 11)
    public static let autoPause = BMAPAddress(1, 24)
    public static let autoAnswer = BMAPAddress(1, 27)

    public static let battery = BMAPAddress(2, 2)

    public static let deviceList = BMAPAddress(4, 4)
    public static let deviceInfo = BMAPAddress(4, 5)
    public static let pairing = BMAPAddress(4, 8)
    public static let routing = BMAPAddress(4, 12)

    public static let source = BMAPAddress(5, 1)

    public static let power = BMAPAddress(7, 4)

    public static let notifications = BMAPAddress(9, 2)

    public static let modeList = BMAPAddress(31, 1)
    public static let modeIndices = BMAPAddress(31, 2)
    public static let currentMode = BMAPAddress(31, 3)
    public static let defaultMode = BMAPAddress(31, 4)
    public static let modeConfiguration = BMAPAddress(31, 6)
    public static let favorites = BMAPAddress(31, 8)
    public static let audioSettings = BMAPAddress(31, 10)
}
