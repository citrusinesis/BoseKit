import Foundation
import Observation
import BoseKitEngine

@MainActor @Observable
final class DeviceController: Identifiable {
    enum Connection: Equatable {
        case disconnected, connecting, connected
    }

    private struct ModeSelection {
        var confirmed: UInt8?
        var outstanding = 0
    }

    private struct RefreshPreempted: Error {}

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
    @ObservationIgnored private var modeSelection: ModeSelection?
    @ObservationIgnored private let actions = ActionQueue()
    @ObservationIgnored private var deferredRefresh: RefreshScope?
    @ObservationIgnored private var maintenanceTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: (scope: RefreshScope, task: Task<Void, Never>)?
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
        modeSelection = nil
        let old = device
        device = nil
        await old?.close()
    }

    func powerOff() async {
        await perform { device in
            self.isSuspended = true
            do {
                try await device.powerOff()
            } catch {
                if !Self.dropsConnection(error) { self.isSuspended = false }
                throw error
            }
            await self.disconnect()
        }
    }

    func refresh(_ scope: RefreshScope = .full) async {
        while let inFlight = refreshTask {
            await inFlight.task.value
            if inFlight.scope >= scope { return }
        }
        guard connected, let device else { return }
        guard !busy else {
            deferRefresh(scope)
            return
        }
        let task = Task {
            await self.read(scope, from: device)
            self.refreshTask = nil
        }
        refreshTask = (scope, task)
        await task.value
    }

    private func deferRefresh(_ scope: RefreshScope) {
        deferredRefresh = max(deferredRefresh ?? scope, scope)
    }

    private func read(_ scope: RefreshScope, from device: BoseDevice) async {
        defer { refreshRevision += 1; lastProbe = Date() }
        do {
            var snapshot = DeviceSnapshot()
            snapshot.battery = try await read(BoseFeatures.battery, in: scope, from: device)
            if scope >= .live {
                if profile.supports(.currentMode) {
                    try yieldToWaitingAction()
                    snapshot.currentMode = try await device.currentMode()
                }
                snapshot.cnc = try await read(BoseFeatures.cnc, in: scope, from: device)
                snapshot.anr = try await read(BoseFeatures.anr, in: scope, from: device)
                snapshot.equalizer = try await read(BoseFeatures.equalizer, in: scope, from: device) ?? []
                snapshot.audio = try await read(BoseFeatures.audioSettings, in: scope, from: device)
            }
            if scope == .full {
                snapshot.name = try await read(BoseFeatures.name, in: scope, from: device)
                snapshot.firmware = firmware
                snapshot.serial = serial
                snapshot.modelName = modelName
                if firmware == nil { snapshot.firmware = try await read(BoseFeatures.firmware, in: scope, from: device) }
                if serial == nil { snapshot.serial = try await read(BoseFeatures.serial, in: scope, from: device) }
                if modelName == nil { snapshot.modelName = try await read(BoseFeatures.model, in: scope, from: device) }
                snapshot.multipoint = try await read(BoseFeatures.multipoint, in: scope, from: device)
                snapshot.autoPause = try await read(BoseFeatures.autoPause, in: scope, from: device)
                snapshot.autoAnswer = try await read(BoseFeatures.autoAnswer, in: scope, from: device)
                snapshot.pairing = try await read(BoseFeatures.pairing, in: scope, from: device)
                snapshot.sidetone = try await read(BoseFeatures.sidetone, in: scope, from: device)
                snapshot.voicePrompts = try await read(BoseFeatures.voicePrompts, in: scope, from: device)
                snapshot.buttons = try await read(BoseFeatures.buttons, in: scope, from: device)
                snapshot.source = try await read(BoseFeatures.source, in: scope, from: device)
                snapshot.favorites = try await read(BoseFeatures.favorites, in: scope, from: device)
                snapshot.defaultMode = try await read(BoseFeatures.defaultMode, in: scope, from: device)
                if profile.supports(.modes) {
                    try yieldToWaitingAction()
                    snapshot.modes = try await device.modes()
                }
                snapshot.sourceDevices = try await readIfAvailable(.sourceDevices, in: scope) {
                    try await device.sourceDevices()
                } ?? []
            }
            apply(snapshot, scope: scope)
            if let deferredRefresh, scope >= deferredRefresh { self.deferredRefresh = nil }
        } catch is RefreshPreempted {
            deferRefresh(scope)
        } catch {
            await handle(error)
        }
    }

    private func yieldToWaitingAction() throws {
        if !actions.isEmpty { throw RefreshPreempted() }
    }

    private func read<V, I>(_ feature: BoseFeature<V, I>, in scope: RefreshScope,
                            from device: BoseDevice) async throws -> V? {
        try await readIfAvailable(feature.id, in: scope) { try await device.read(feature) }
    }

    private func readIfAvailable<T>(_ feature: FeatureID, in scope: RefreshScope,
                                    _ request: () async throws -> T) async throws -> T? {
        guard profile.supports(feature), scope == .full || !unavailable.contains(feature) else { return nil }
        try yieldToWaitingAction()
        do {
            let value = try await request()
            if unavailable.contains(feature) { unavailable.remove(feature) }
            return value
        } catch BoseError.device {
            if !unavailable.contains(feature) { unavailable.insert(feature) }
            return nil
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
        guard modeSelection == nil else { return }
        currentMode = snapshot.currentMode
        cnc = snapshot.cnc
        anr = snapshot.anr
        equalizer = snapshot.equalizer
        audio = snapshot.audio ?? modes.first { $0.id == snapshot.currentMode }?.audio
    }

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

    @discardableResult
    func perform(refreshing scope: RefreshScope = .full,
                 _ action: @MainActor (BoseDevice) async throws -> Void) async -> Bool {
        if actions.isEmpty { error = nil }
        busy = true
        await actions.enter()
        await refreshTask?.task.value
        var succeeded = false
        if connected, let device {
            do {
                try await action(device)
                succeeded = true
                deferRefresh(scope)
            } catch {
                await handle(error)
                deferRefresh(.full)
            }
        }
        actions.leave()
        if actions.isEmpty {
            busy = false
            if connected, let deferredRefresh { await refresh(deferredRefresh) }
        }
        return succeeded
    }

    @discardableResult
    func selectMode(_ slot: UInt8) -> Task<Bool, Never>? {
        guard connected, currentMode != slot else { return nil }
        var selection = modeSelection ?? ModeSelection(confirmed: currentMode)
        selection.outstanding += 1
        modeSelection = selection
        currentMode = slot
        if let modeAudio = modes.first(where: { $0.id == slot })?.audio { audio = modeAudio }
        return send(refreshing: .live) { device in
            defer { self.settleModeSelection() }
            try await device.selectMode(slot)
            self.modeSelection?.confirmed = slot
        }
    }

    private func settleModeSelection() {
        guard var selection = modeSelection else { return }
        selection.outstanding -= 1
        guard selection.outstanding == 0 else {
            modeSelection = selection
            return
        }
        modeSelection = nil
        if currentMode != selection.confirmed { currentMode = selection.confirmed }
    }

    @discardableResult
    func send(refreshing scope: RefreshScope = .full,
              _ action: @escaping @MainActor (BoseDevice) async throws -> Void) -> Task<Bool, Never> {
        Task { await perform(refreshing: scope, action) }
    }

    private func handle(_ error: any Error) async {
        self.error = AppError(error)
        guard Self.dropsConnection(error) else { return }
        failures += 1
        retryAfter = Date().addingTimeInterval(policy.retryDelay(afterFailures: failures))
        await disconnect(suspend: isSuspended)
    }

    private static func dropsConnection(_ error: any Error) -> Bool {
        switch error as? BoseError {
        case .disconnected?, .timeout?, .transport?: true
        default: false
        }
    }
}
