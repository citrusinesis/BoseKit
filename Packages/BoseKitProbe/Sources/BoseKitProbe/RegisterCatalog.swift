import BoseKitEngine
import Foundation

enum RegisterCatalog {
    static let names: [BMAPAddress: String] = [
        BMAPAddress(0, 0): "block info",
        .productInfo: "product info",
        .firmware: "firmware",
        .serial: "serial",
        .model: "model",

        BMAPAddress(1, 0): "block info",
        .name: "name",
        .voicePrompts: "voice prompts",
        BMAPAddress(1, 4): "standby timer",
        .cnc: "cnc",
        .anr: "anr",
        .equalizer: "equalizer",
        .buttons: "buttons",
        .multipoint: "multipoint",
        .sidetone: "sidetone",
        BMAPAddress(1, 12): "setup complete",
        BMAPAddress(1, 14): "cnc persistence",
        BMAPAddress(1, 15): "cnc presets",
        BMAPAddress(1, 16): "on-head detection",
        .autoPause: "auto pause",
        .autoAnswer: "auto answer",
        BMAPAddress(1, 29): "auto aware mode",

        BMAPAddress(2, 0): "block info",
        .battery: "battery",
        BMAPAddress(2, 3): "aux cable",
        BMAPAddress(2, 5): "charger detect",
        BMAPAddress(2, 9): "in ear",
        BMAPAddress(2, 12): "button",

        BMAPAddress(3, 0): "block info",

        BMAPAddress(4, 0): "block info",
        BMAPAddress(4, 1): "connect",
        .deviceList: "device list",
        .deviceInfo: "device info",
        .pairing: "pairing",
        BMAPAddress(4, 9): "host address",
        .routing: "routing",

        BMAPAddress(5, 0): "block info",
        .source: "source",
        BMAPAddress(5, 3): "audio control",

        BMAPAddress(6, 0): "block info",

        BMAPAddress(7, 0): "block info",
        .power: "power",
        BMAPAddress(7, 5): "factory default",
        BMAPAddress(7, 6): "ship mode",
        BMAPAddress(7, 7): "anr only",
        BMAPAddress(7, 11): "reset",

        BMAPAddress(9, 0): "block info",
        .notifications: "notifications",

        BMAPAddress(31, 0): "block info",
        .modeList: "mode list",
        .modeIndices: "mode indices",
        .currentMode: "current mode",
        .defaultMode: "default mode",
        .modeConfiguration: "mode config",
        .favorites: "favorites",
        BMAPAddress(31, 9): "mode reset",
        .audioSettings: "audio settings",
        BMAPAddress(31, 11): "names supported",
    ]

    private static let addressWidth = 8
    private static let nameWidth = names.values.map(\.count).max() ?? 0

    static func column(for address: BMAPAddress) -> String {
        "[\(address.block).\(address.function)]".padding(toLength: addressWidth, withPad: " ", startingAt: 0)
            + (names[address] ?? "").padding(toLength: nameWidth, withPad: " ", startingAt: 0)
    }
}
