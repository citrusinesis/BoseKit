import Foundation
import Observation
import BoseKitEngine

@MainActor @Observable
final class DeviceController: Identifiable {
    enum Connection: Equatable {
        case disconnected, connecting, connected
    }

    let id: String
    let profile: DeviceProfile
    private(set) var name: String
    var nativeConnected = false
    private(set) var connection: Connection = .disconnected
    private(set) var busy = false
    private(set) var isSuspended = false
    private(set) var error: AppError?
    private(set) var refreshRevision = 0
    private(set) var unavailable: Set<FeatureID> = []

    private(set) var battery: BatteryStatus?
    private(set) var firmware: String?
    private(set) var serial: String?
    private(set) var modelName: String?
    private(set) var equalizer: [EQBand] = []
    private(set) var cnc: CNCStatus?
    private(set) var anr: ANRLevel?
    private(set) var audio: AudioSettings?
    private(set) var modes: [ModeConfiguration] = []
    private(set) var selectableModes: [ModeConfiguration] = []
    private(set) var currentMode: UInt8?
    private(set) var defaultMode: UInt8?
    private(set) var favorites: FavoriteModes?
    private(set) var multipoint: Bool?
    private(set) var autoPause: Bool?
    private(set) var autoAnswer: Bool?
    private(set) var pairing: Bool?
    private(set) var sidetone: SidetoneLevel?
    private(set) var voicePrompts: VoicePrompts?
    private(set) var buttons: ButtonConfiguration?
    private(set) var source: AudioSource?
    private(set) var sourceDevices: [SourceDevice] = []

    @ObservationIgnored private var device: BoseDevice?
    @ObservationIgnored private let policy: MaintenancePolicy
    @ObservationIgnored private var retryAfter = Date.distantPast
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var lastProbe = Date.distantPast
    @ObservationIgnored private var lastFullRefresh = Date.distantPast
    @ObservationIgnored private var visibleViews = 0
    @ObservationIgnored private var editingSessions = 0
    @ObservationIgnored private var pendingMode: UInt8?
    @ObservationIgnored private var waitingActions = 0
    @ObservationIgnored private var maintenanceTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private let connectDevice: @MainActor (String, DeviceProfile) async throws -> BoseDevice

    init(id: String, name: String, profile: DeviceProfile, policy: MaintenancePolicy = .standard,
         connectDevice: @escaping @MainActor (String, DeviceProfile) async throws -> BoseDevice = { address, profile in
             try await BoseDevice.connect(profile: profile,
                 transport: RFCOMMTransport(address: address, channel: profile.rfcommChannel))
         }) {
        self.id = id
        self.name = name
        self.profile = profile
        self.policy = policy
        self.connectDevice = connectDevice
    }

    var connected: Bool { connection == .connected }
    var connecting: Bool { connection == .connecting }

    func supports(_ feature: FeatureID, write: Bool = false) -> Bool {
        profile.supports(feature, access: write ? .write : .read) && !unavailable.contains(feature)
    }

    func attachView() { visibleViews += 1 }
    func detachView() { visibleViews = max(0, visibleViews - 1) }

    func setEditing(_ active: Bool) {
        editingSessions = active ? editingSessions + 1 : max(0, editingSessions - 1)
    }

    func scheduleMaintenance() {
        guard maintenanceTask == nil else { return }
        maintenanceTask = Task {
            await maintain()
            maintenanceTask = nil
        }
    }

    func maintain() async {
        if connected {
            if visibleViews > 0 && editingSessions == 0 {
                let fullDue = Date().timeIntervalSince(lastFullRefresh) >= policy.fullRefreshInterval
                await refresh(fullDue ? .full : .live)
            } else if !busy && Date().timeIntervalSince(lastProbe) >= policy.idleProbeInterval {
                await refresh(.probe)
            }
            return
        }
        guard !isSuspended, connection == .disconnected, Date() >= retryAfter else { return }
        await connect()
    }

    func connect() async {
        guard connection == .disconnected, !busy else { return }
        connection = .connecting
        isSuspended = false
        error = nil
        do {
            device = try await connectDevice(id, profile)
            connection = .connected
            failures = 0
            unavailable = []
            await refresh()
        } catch {
            connection = .disconnected
            await handle(error)
        }
    }

    func disconnect(suspend: Bool = true) async {
        isSuspended = suspend
        connection = .disconnected
        let old = device
        device = nil
        await old?.close()
    }

    func refresh(_ scope: RefreshScope = .full) async {
        if let refreshTask { await refreshTask.value; return }
        guard connected, !busy, let device else { return }
        let task = Task {
            await self.read(scope, from: device)
            self.refreshTask = nil
        }
        refreshTask = task
        await task.value
    }

    private func read(_ scope: RefreshScope, from device: BoseDevice) async {
        defer { refreshRevision += 1; lastProbe = Date() }
        do {
            var snapshot = DeviceSnapshot()
            snapshot.battery = try await read(BoseFeatures.battery, from: device)
            if scope != .probe {
                if supports(.currentMode) {
                    try yieldToWaitingAction()
                    snapshot.currentMode = try await device.currentMode()
                }
                snapshot.cnc = try await read(BoseFeatures.cnc, from: device)
                snapshot.anr = try await read(BoseFeatures.anr, from: device)
                snapshot.equalizer = try await read(BoseFeatures.equalizer, from: device) ?? []
                snapshot.audio = try await read(BoseFeatures.audioSettings, from: device)
            }
            if scope == .full {
                snapshot.name = try await read(BoseFeatures.name, from: device)
                snapshot.firmware = firmware
                snapshot.serial = serial
                snapshot.modelName = modelName
                if firmware == nil { snapshot.firmware = try await read(BoseFeatures.firmware, from: device) }
                if serial == nil { snapshot.serial = try await read(BoseFeatures.serial, from: device) }
                if modelName == nil { snapshot.modelName = try await read(BoseFeatures.model, from: device) }
                snapshot.multipoint = try await read(BoseFeatures.multipoint, from: device)
                snapshot.autoPause = try await read(BoseFeatures.autoPause, from: device)
                snapshot.autoAnswer = try await read(BoseFeatures.autoAnswer, from: device)
                snapshot.pairing = try await read(BoseFeatures.pairing, from: device)
                snapshot.sidetone = try await read(BoseFeatures.sidetone, from: device)
                snapshot.voicePrompts = try await read(BoseFeatures.voicePrompts, from: device)
                snapshot.buttons = try await read(BoseFeatures.buttons, from: device)
                snapshot.source = try await read(BoseFeatures.source, from: device)
                snapshot.favorites = try await read(BoseFeatures.favorites, from: device)
                snapshot.defaultMode = try await read(BoseFeatures.defaultMode, from: device)
                if supports(.modes) {
                    try yieldToWaitingAction()
                    snapshot.modes = try await device.modes()
                }
                snapshot.sourceDevices = try await readSourceDevices(from: device)
            }
            apply(snapshot, scope: scope)
        } catch is RefreshPreempted {
            return
        } catch {
            await handle(error)
        }
    }

    private struct RefreshPreempted: Error {}

    private func yieldToWaitingAction() throws {
        if waitingActions > 0 { throw RefreshPreempted() }
    }

    private func read<V, I>(_ feature: BoseFeature<V, I>, from device: BoseDevice) async throws -> V? {
        guard supports(feature.id) else { return nil }
        try yieldToWaitingAction()
        do {
            return try await device.read(feature)
        } catch BoseError.device {
            unavailable.insert(feature.id)
            return nil
        }
    }

    private func readSourceDevices(from device: BoseDevice) async throws -> [SourceDevice] {
        guard supports(.sourceDevices) else { return [] }
        try yieldToWaitingAction()
        do {
            return try await device.sourceDevices()
        } catch BoseError.device {
            unavailable.insert(.sourceDevices)
            return []
        }
    }

    private func apply(_ snapshot: DeviceSnapshot, scope: RefreshScope) {
        battery = snapshot.battery
        guard scope != .probe else { return }
        if scope == .full {
            if let name = snapshot.name { self.name = name }
            firmware = snapshot.firmware
            serial = snapshot.serial
            modelName = snapshot.modelName
            setModes(snapshot.modes)
            defaultMode = snapshot.defaultMode
            favorites = snapshot.favorites
            multipoint = snapshot.multipoint
            autoPause = snapshot.autoPause
            autoAnswer = snapshot.autoAnswer
            pairing = snapshot.pairing
            sidetone = snapshot.sidetone
            voicePrompts = snapshot.voicePrompts
            buttons = snapshot.buttons
            source = snapshot.source
            sourceDevices = snapshot.sourceDevices
            lastFullRefresh = Date()
        }
        guard pendingMode == nil else { return }
        currentMode = snapshot.currentMode
        cnc = snapshot.cnc
        anr = snapshot.anr
        equalizer = snapshot.equalizer
        audio = snapshot.audio ?? modes.first { $0.id == snapshot.currentMode }?.audio
    }

    @discardableResult
    private func setModes(_ newModes: [ModeConfiguration]) {
        modes = newModes
        selectableModes = newModes.filter { profile.modePolicy?.isSelectable($0) == true }
    }

    func applyConfirmedAudio(_ newAudio: AudioSettings) {
        audio = newAudio
        guard profile.noiseControl == .modeConfiguration,
              let index = modes.firstIndex(where: { $0.id == currentMode }) else { return }
        let mode = modes[index]
        var updated = modes
        updated[index] = ModeConfiguration(id: mode.id, prompt: mode.prompt, name: mode.name,
                                           editable: mode.editable, configured: mode.configured,
                                           favorite: mode.favorite, audio: newAudio, rawPayload: mode.rawPayload)
        setModes(updated)
    }

    func perform(refreshing scope: RefreshScope = .full,
                 _ action: @MainActor (BoseDevice) async throws -> Void) async -> Bool {
        waitingActions += 1
        await refreshTask?.value
        waitingActions -= 1
        guard connected, !busy, let device else { return false }
        busy = true
        error = nil
        do {
            try await action(device)
            busy = false
            await refresh(scope)
            return connected
        } catch {
            busy = false
            await handle(error)
            if connected { await refresh() }
            return false
        }
    }

    func selectMode(_ slot: UInt8) {
        guard connected, !busy, currentMode != slot else { return }
        let confirmed = currentMode
        pendingMode = slot
        currentMode = slot
        if let modeAudio = modes.first(where: { $0.id == slot })?.audio { audio = modeAudio }
        Task {
            await perform(refreshing: .live) { device in
                defer { self.pendingMode = nil }
                try await device.selectMode(slot)
            }
            if pendingMode == slot {
                pendingMode = nil
                currentMode = confirmed
            }
        }
    }

    func send(refreshing scope: RefreshScope = .full,
              _ action: @escaping @MainActor (BoseDevice) async throws -> Void) {
        Task { await perform(refreshing: scope, action) }
    }

    func suspendBeforePowerOff() { isSuspended = true }

    private func handle(_ error: any Error) async {
        self.error = AppError(error)
        switch error as? BoseError {
        case .disconnected?, .timeout?, .transport?:
            failures += 1
            retryAfter = Date().addingTimeInterval(policy.retryDelay(afterFailures: failures))
            await disconnect(suspend: isSuspended)
        default:
            break
        }
    }
}
