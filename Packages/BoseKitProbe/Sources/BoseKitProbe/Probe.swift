import BoseKitEngine
import Foundation

@main
struct Probe {
    @MainActor static func main() async {
        setvbuf(stdout, nil, _IOLBF, 0)
        do {
            try await run(ProbeCommand(arguments: Array(CommandLine.arguments.dropFirst())))
        } catch {
            FileHandle.standardError.write(Data("bosekit-probe: \(error)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    @MainActor private static func run(_ command: ProbeCommand) async throws {
        switch command {
        case .help:
            print(ProbeCommand.usage)
        case .list:
            try list()
        case .monitor(let options):
            try await monitor(options)
        }
    }

    private static func targets() throws(ProbeError) -> [ProbeTarget] {
        do throws(PairedDeviceListingError) {
            return ProbeTarget.merging(try RFCOMMTransport.pairedDevices(), registry: .standard)
        } catch {
            switch error {
            case .systemListUnavailable: throw .pairedDevicesUnavailable
            }
        }
    }

    private static func list() throws(ProbeError) {
        for target in try targets() {
            let state = target.isConnected ? "connected" : "not connected"
            print("\(target.address)  \(target.profileID ?? "unsupported")  \(state)  \(target.name)")
        }
    }

    private static func target(for address: BluetoothAddress?) throws(ProbeError) -> (ProbeTarget, DeviceProfile) {
        let supported = try targets().compactMap { target in
            DeviceRegistry.standard.profiles.first { $0.id == target.profileID }.map { (target, $0) }
        }
        if let address {
            guard let match = supported.first(where: { BluetoothAddress(string: $0.0.address) == address }) else {
                throw .deviceNotPaired(address.description)
            }
            return match
        }
        guard let first = supported.first else { throw .noSupportedDevice }
        guard supported.count == 1 else { throw .ambiguousDevices(supported.map(\.0.address)) }
        return first
    }

    @MainActor private static func monitor(_ options: MonitorOptions) async throws {
        let (target, profile) = try target(for: options.address)
        let work = Task { try await Monitor.run(target, profile: profile, options: options) }
        let interrupt = cancelOnInterrupt(work)
        defer { interrupt.cancel() }
        try await work.value
    }

    private static func cancelOnInterrupt(_ work: Task<Void, any Error>) -> any DispatchSourceSignal {
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler { work.cancel() }
        source.resume()
        return source
    }
}
