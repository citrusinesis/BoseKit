import Foundation
import Observation
import os
import BoseKitEngine

@MainActor @Observable
final class BoseAppModel {
    typealias PairedDeviceListing = @Sendable () throws(PairedDeviceListingError) -> [PairedBluetoothDevice]

    private enum DefaultsKey {
        static let hideWhenUnavailable = "hideWhenUnavailable"
        static let showBattery = "showBattery"
        static let selectedDeviceID = "selectedDeviceID"
    }

    private static let logger = Logger(subsystem: "dev.jihosong.BoseKit", category: "discovery")

    private(set) var devices: [DeviceController] = []

    var selectedID: String? {
        didSet { defaults.set(selectedID, forKey: DefaultsKey.selectedDeviceID) }
    }

    var hideWhenUnavailable: Bool {
        didSet {
            defaults.set(hideWhenUnavailable, forKey: DefaultsKey.hideWhenUnavailable)
            menuRemovedByUser = false
        }
    }

    var showBattery: Bool {
        didSet { defaults.set(showBattery, forKey: DefaultsKey.showBattery) }
    }

    @ObservationIgnored private let policy: MaintenancePolicy
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let userDisconnects: UserDisconnectStore
    @ObservationIgnored private let registry: DeviceRegistry
    @ObservationIgnored private let listPairedDevices: PairedDeviceListing
    @ObservationIgnored private let connectDevice: DeviceController.Connector
    @ObservationIgnored private var monitor: Task<Void, Never>?
    @ObservationIgnored private var discovering = false
    private var menuRemovedByUser = false

    init(policy: MaintenancePolicy = .standard, defaults: UserDefaults = .standard,
         registry: DeviceRegistry = .standard,
         listPairedDevices: @escaping PairedDeviceListing = RFCOMMTransport.pairedDevices,
         connectDevice: @escaping DeviceController.Connector = DeviceController.connectOverRFCOMM) {
        self.policy = policy
        self.defaults = defaults
        self.userDisconnects = UserDisconnectStore(defaults: defaults)
        self.registry = registry
        self.listPairedDevices = listPairedDevices
        self.connectDevice = connectDevice
        hideWhenUnavailable = defaults.bool(forKey: DefaultsKey.hideWhenUnavailable)
        showBattery = defaults.bool(forKey: DefaultsKey.showBattery)
        selectedID = defaults.string(forKey: DefaultsKey.selectedDeviceID)
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
        do {
            try await syncPairedDevices()
        } catch {
            Self.logger.error("Listing paired devices failed: \(String(describing: error), privacy: .public)")
        }
    }

    func syncPairedDevices() async throws(PairedDeviceListingError) {
        guard !discovering else { return }
        discovering = true
        defer { discovering = false }
        let listPairedDevices = self.listPairedDevices
        let listing = await Task.detached(priority: .utility) {
            Result { () throws(PairedDeviceListingError) in try listPairedDevices() }
        }.value
        await reconcile(with: try listing.get())
    }

    private func reconcile(with paired: [PairedBluetoothDevice]) async {
        let supported = paired.compactMap { item in item.profile(in: registry).map { (item, $0) } }
        let pairedIDs = Set(supported.map(\.0.id))
        for device in devices where !pairedIDs.contains(device.id) {
            await device.closeConnection()
        }
        devices.removeAll { !pairedIDs.contains($0.id) }
        userDisconnects.keepOnly(pairedIDs)
        for (item, profile) in supported where !devices.contains(where: { $0.id == item.id }) {
            devices.append(makeController(for: item, profile: profile))
        }
        reconcileSelection()
    }

    private func makeController(for item: PairedBluetoothDevice, profile: DeviceProfile) -> DeviceController {
        let id = item.id
        return DeviceController(id: id, name: item.name, profile: profile, policy: policy,
                                autoConnectPause: userDisconnects.contains(id) ? .userDisconnected : nil,
                                connectDevice: connectDevice,
                                onEvent: { [weak self] event in self?.handle(event, from: id) })
    }

    private func handle(_ event: DeviceController.Event, from id: String) {
        guard let device = devices.first(where: { $0.id == id }) else { return }
        switch event {
        case .connectionEstablished:
            selectAfterConnecting(device)
        case .connectionLost:
            selectAfterLosing(device)
        case .autoConnectPauseChanged(let pause):
            userDisconnects.set(pause == .userDisconnected, for: id)
        }
    }
}
