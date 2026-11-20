import BoseKitEngine

struct MonitorOptions: Equatable {
    var address: BluetoothAddress?
    var subscription: NotificationBlocks?
    var snapshots: SnapshotOptions?
}

enum ProbeCommand: Equatable {
    case help
    case list
    case monitor(MonitorOptions)

    static let usage = """
        Usage:
          bosekit-probe list
              Show paired Bose devices and the profile each one matches.
          bosekit-probe monitor [--address <AA:BB:CC:DD:EE:FF>] [--subscribe <blocks>]
                                [--snapshots [--snapshot-registers <registers>] [--skip-registers <registers>]]
              Connect, read the notification subscription, and print every packet until interrupted.
              --subscribe takes comma-separated function blocks (for example 1,2,4,5,31) or 'none' to clear it.
              Without --subscribe nothing is written to the device.
              --snapshots reads one label per line from standard input and takes a snapshot for each line.
              A snapshot GETs every snapshot register and prints what changed since the previous snapshot.
              The first snapshot lists every register that answered or returned a device error.
              With --snapshots only unsolicited packets are printed as events.
              A register that does not answer within \(SnapshotOptions.requestTimeout.components.seconds) s is skipped from then on, and the session reconnects.
              --snapshot-registers replaces the default snapshot set; --skip-registers removes registers from it.
              Both take comma-separated <block>.<function> pairs, for example 2.5,2.9.
        """

    init(arguments: [String]) throws(ProbeError) {
        guard let name = arguments.first else {
            self = .help
            return
        }
        let options = arguments.dropFirst()
        switch name {
        case "help", "--help", "-h":
            self = .help
        case "list":
            guard options.isEmpty else { throw .usage("'list' takes no options.") }
            self = .list
        case "monitor":
            self = .monitor(try Self.monitorOptions(options))
        default:
            throw .usage("Unknown command '\(name)'.")
        }
    }

    private static func monitorOptions(_ arguments: ArraySlice<String>) throws(ProbeError) -> MonitorOptions {
        var options = MonitorOptions()
        var remaining = arguments
        var takesSnapshots = false
        var registerList: String?
        var skipList: String?
        while let flag = remaining.popFirst() {
            if flag == "--snapshots" {
                takesSnapshots = true
                continue
            }
            guard let value = remaining.popFirst() else { throw .usage("\(flag) needs a value.") }
            switch flag {
            case "--address":
                guard let address = BluetoothAddress(string: value) else {
                    throw .usage("'\(value)' is not a Bluetooth address.")
                }
                options.address = address
            case "--subscribe":
                options.subscription = try NotificationBlocks(list: value)
            case "--snapshot-registers":
                registerList = value
            case "--skip-registers":
                skipList = value
            default:
                throw .usage("Unknown option '\(flag)'.")
            }
        }
        if takesSnapshots {
            options.snapshots = try SnapshotOptions(registerList: registerList, skipList: skipList)
        } else if registerList != nil || skipList != nil {
            throw .usage("--snapshot-registers and --skip-registers need --snapshots.")
        }
        return options
    }
}
