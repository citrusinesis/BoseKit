import Foundation
import Observation
import BoseKitEngine

@MainActor @Observable
final class BoseAppModel {
    private enum DefaultsKey {
        static let hideWhenUnavailable = "hideWhenUnavailable"
        static let showBattery = "showBattery"
    }

    var devices: [DeviceController] = []
    var selectedID: String?
    private(set) var discoveryError: AppError?

    var hideWhenUnavailable = UserDefaults.standard.bool(forKey: DefaultsKey.hideWhenUnavailable) {
        didSet {
            UserDefaults.standard.set(hideWhenUnavailable, forKey: DefaultsKey.hideWhenUnavailable)
            menuRemovedByUser = false
        }
    }

    var showBattery = UserDefaults.standard.bool(forKey: DefaultsKey.showBattery) {
        didSet { UserDefaults.standard.set(showBattery, forKey: DefaultsKey.showBattery) }
    }

    @ObservationIgnored private let policy: MaintenancePolicy
    @ObservationIgnored private var registry: DeviceRegistry?
    @ObservationIgnored private var monitor: Task<Void, Never>?
    @ObservationIgnored private var discovering = false
    private var menuRemovedByUser = false

    init(policy: MaintenancePolicy = .standard) {
        self.policy = policy
    }

    var selected: DeviceController? { devices.first { $0.id == selectedID } ?? devices.first }

    static func shouldShowMenu(hide: Bool, hasConnectedDevice: Bool) -> Bool {
        !hide || hasConnectedDevice
    }

    private var shouldShowMenu: Bool {
        Self.shouldShowMenu(hide: hideWhenUnavailable, hasConnectedDevice: devices.contains { $0.connected })
    }

    var menuInserted: Bool {
        get { !menuRemovedByUser && shouldShowMenu }
        set {
            if newValue {
                menuRemovedByUser = false
            } else if shouldShowMenu {
                menuRemovedByUser = true
            }
        }
    }

    var menuBatteryPercentage: UInt8? {
        guard showBattery else { return nil }
        let device = selected.flatMap { $0.connected ? $0 : nil } ?? devices.first { $0.connected }
        return device?.battery?.percentage
    }

    func start() {
        guard monitor == nil else { return }
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard environment["BOSEKIT_DISABLE_BLUETOOTH"] != "1",
              environment["XCTestConfigurationFilePath"] == nil else { return }
        #endif
        let interval = policy.discoveryInterval
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.discover()
                for device in self.devices { device.scheduleMaintenance() }
                try? await Task.sleep(for: interval)
            }
        }
    }

    func discover() async {
        guard !discovering else { return }
        discovering = true
        defer { discovering = false }
        do {
            if registry == nil { registry = try DeviceRegistry.standard() }
            guard let registry else { return }
            let paired = await Task.detached(priority: .utility) {
                RFCOMMTransport.pairedDevices()
            }.value
            var connectedIDs: Set<String> = []
            for item in paired {
                guard let profile = item.profile(in: registry) else { continue }
                if !devices.contains(where: { $0.id == item.id }) {
                    devices.append(DeviceController(id: item.id, name: item.name, profile: profile, policy: policy))
                }
                if item.isConnected { connectedIDs.insert(item.id) }
            }
            for device in devices { device.nativeConnected = connectedIDs.contains(device.id) }
            if selectedID == nil || (selected?.nativeConnected == false && selected?.connected == false) {
                selectedID = devices.first(where: \.nativeConnected)?.id ?? selectedID ?? devices.first?.id
            }
            discoveryError = nil
        } catch {
            discoveryError = AppError(error)
        }
    }
}
