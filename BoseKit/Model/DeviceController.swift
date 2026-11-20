import Foundation
import Observation
import BoseKitEngine

@MainActor @Observable
final class DeviceController: Identifiable {
    typealias Connector = @MainActor (String, DeviceProfile) async throws -> BoseDevice
    typealias Action = @MainActor (BoseDevice) async throws -> ConfirmedChange?

    enum Connection: Equatable {
        case disconnected, connecting, connected
    }

    enum AutoConnectPause: Equatable {
        case userDisconnected, poweredOff
    }

    enum Event: Equatable {
        case connectionEstablished
        case connectionLost
        case autoConnectPauseChanged(AutoConnectPause?)
    }

    private struct RefreshPreempted: Error {}

    let id: String
    let profile: DeviceProfile
    private(set) var name: String
    private(set) var connection: Connection = .disconnected {
        didSet {
            switch (oldValue == .connected, connection == .connected) {
            case (false, true): onEvent(.connectionEstablished)
            case (true, false): onEvent(.connectionLost)
            default: break
            }
        }
    }
    private(set) var busy = false
    private(set) var autoConnectPause: AutoConnectPause? {
        didSet {
            if autoConnectPause != oldValue { onEvent(.autoConnectPauseChanged(autoConnectPause)) }
        }
    }
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
    @ObservationIgnored let pending = PendingChanges()

    @ObservationIgnored private var device: BoseDevice?
    @ObservationIgnored private var permanentlyUnavailable: Set<FeatureID> = []
    @ObservationIgnored private let policy: MaintenancePolicy
    @ObservationIgnored private var retryAfter = Date.distantPast
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var lastProbe = Date.distantPast
    @ObservationIgnored private var lastFullRefresh = Date.distantPast
    @ObservationIgnored private var visibleViews = 0
    @ObservationIgnored private var editingSessions = 0
    @ObservationIgnored private let actions = ActionQueue()
    @ObservationIgnored private var deferredRefresh: RefreshScope?
    @ObservationIgnored private var maintenanceTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: (scope: RefreshScope, task: Task<Void, Never>)?
    @ObservationIgnored private var connectionGeneration = 0
    @ObservationIgnored private let connectDevice: Connector
    @ObservationIgnored private let onEvent: @MainActor (Event) -> Void

    init(id: String, name: String, profile: DeviceProfile, policy: MaintenancePolicy = .standard,
         autoConnectPause: AutoConnectPause? = nil,
         connectDevice: @escaping Connector = DeviceController.connectOverRFCOMM,
         onEvent: @escaping @MainActor (Event) -> Void = { _ in }) {
        self.id = id
        self.name = name
        self.profile = profile
        self.policy = policy
        self.autoConnectPause = autoConnectPause
        self.connectDevice = connectDevice
        self.onEvent = onEvent
    }

    static func connectOverRFCOMM(address: String, profile: DeviceProfile) async throws -> BoseDevice {
        try await BoseDevice.connect(profile: profile,
            transport: RFCOMMTransport(address: address, channel: profile.rfcommChannel))
    }

    var connected: Bool { connection == .connected }
    var isSuspended: Bool { autoConnectPause != nil }
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
        autoConnectPause = nil
        error = nil
        let generation = connectionGeneration
        do {
            let opened = try await connectDevice(id, profile)
            guard generation == connectionGeneration else {
                await opened.close()
                return
            }
            device = opened
            connection = .connected
            failures = 0
            unavailable = []
            permanentlyUnavailable = []
            await refresh()
        } catch {
            guard generation == connectionGeneration else { return }
            connection = .disconnected
            await handle(error)
        }
    }

    func disconnect() async {
        autoConnectPause = .userDisconnected
        await closeConnection()
    }

    func closeConnection() async {
        connectionGeneration += 1
        connection = .disconnected
        pending.clear()
        let old = device
        device = nil
        await old?.close()
    }

    func powerOff() async {
        await perform { device in
            self.autoConnectPause = .poweredOff
            do {
                try await device.powerOff()
            } catch {
                if !Self.dropsConnection(error) { self.autoConnectPause = nil }
                throw error
            }
            await self.closeConnection()
            return nil
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
        func fetch<V, I>(_ feature: BoseFeature<V, I>, keeping current: V?) async throws -> V? {
            try await readIfAvailable(feature.id, in: scope, keeping: current) { try await device.read(feature) }
        }
        do {
            var snapshot = DeviceSnapshot()
            snapshot.battery = try await fetch(BoseFeatures.battery, keeping: battery)
            if scope >= .live {
                if profile.supports(.currentMode) {
                    try yieldToWaitingAction()
                    snapshot.currentMode = try await device.currentMode()
                }
                snapshot.cnc = try await fetch(BoseFeatures.cnc, keeping: cnc)
                snapshot.anr = try await fetch(BoseFeatures.anr, keeping: anr)
                snapshot.equalizer = try await fetch(BoseFeatures.equalizer, keeping: equalizer) ?? []
                snapshot.audio = try await fetch(BoseFeatures.audioSettings, keeping: audio)
            }
            if scope == .full {
                snapshot.name = try await fetch(BoseFeatures.name, keeping: name)
                snapshot.firmware = firmware
                snapshot.serial = serial
                snapshot.modelName = modelName
                if firmware == nil { snapshot.firmware = try await fetch(BoseFeatures.firmware, keeping: nil) }
                if serial == nil { snapshot.serial = try await fetch(BoseFeatures.serial, keeping: nil) }
                if modelName == nil { snapshot.modelName = try await fetch(BoseFeatures.model, keeping: nil) }
                snapshot.multipoint = try await fetch(BoseFeatures.multipoint, keeping: multipoint)
                snapshot.autoPause = try await fetch(BoseFeatures.autoPause, keeping: autoPause)
                snapshot.autoAnswer = try await fetch(BoseFeatures.autoAnswer, keeping: autoAnswer)
                snapshot.pairing = try await fetch(BoseFeatures.pairing, keeping: pairing)
                snapshot.sidetone = try await fetch(BoseFeatures.sidetone, keeping: sidetone)
                snapshot.voicePrompts = try await fetch(BoseFeatures.voicePrompts, keeping: voicePrompts)
                snapshot.buttons = try await fetch(BoseFeatures.buttons, keeping: buttons)
                snapshot.source = try await fetch(BoseFeatures.source, keeping: source)
                snapshot.favorites = try await fetch(BoseFeatures.favorites, keeping: favorites)
                snapshot.defaultMode = try await fetch(BoseFeatures.defaultMode, keeping: defaultMode)
                if profile.supports(.modes) {
                    try yieldToWaitingAction()
                    snapshot.modes = try await device.modes()
                }
                snapshot.sourceDevices = try await readIfAvailable(.sourceDevices, in: scope, keeping: sourceDevices) {
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

    private func readIfAvailable<T>(_ feature: FeatureID, in scope: RefreshScope, keeping current: T?,
                                    _ request: () async throws -> T) async throws -> T? {
        guard profile.supports(feature), !permanentlyUnavailable.contains(feature),
              scope == .full || !unavailable.contains(feature) else { return nil }
        try yieldToWaitingAction()
        do {
            let value = try await request()
            if unavailable.contains(feature) { unavailable.remove(feature) }
            return value
        } catch BoseError.device(_, let code, _) {
            switch code?.disposition ?? .indeterminate {
            case .permanent:
                permanentlyUnavailable.insert(feature)
                markUnavailable(feature)
                return nil
            case .transient:
                return current
            case .indeterminate:
                markUnavailable(feature)
                return nil
            }
        }
    }

    private func markUnavailable(_ feature: FeatureID) {
        if !unavailable.contains(feature) { unavailable.insert(feature) }
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

    private func apply(_ change: ConfirmedChange) {
        switch change {
        case .name(let value): name = value
        case .cnc(let value): cnc = value
        case .anr(let value): anr = value
        case .equalizer(let value): equalizer = value
        case .audio(let value): applyConfirmedAudio(value)
        case .currentMode(let value): applyConfirmedCurrentMode(value)
        case .mode(let value): applyConfirmedMode(value)
        case .favorites(let value): favorites = value
        case .defaultMode(let value): defaultMode = value
        case .multipoint(let value): multipoint = value
        case .autoPause(let value): autoPause = value
        case .autoAnswer(let value): autoAnswer = value
        case .pairing(let value): pairing = value
        case .sidetone(let value): sidetone = value
        case .voicePrompts(let value): voicePrompts = value
        case .buttons(let value): buttons = value
        }
        refreshRevision += 1
    }

    private func applyConfirmedAudio(_ newAudio: AudioSettings) {
        audio = newAudio
        guard profile.noiseControl == .modeConfiguration,
              let mode = modes.first(where: { $0.id == currentMode }) else { return }
        replaceMode(ModeConfiguration(id: mode.id, prompt: mode.prompt, name: mode.name, editable: mode.editable,
                                      configured: mode.configured, favorite: mode.favorite, audio: newAudio,
                                      rawPayload: mode.rawPayload))
    }

    private func applyConfirmedCurrentMode(_ slot: UInt8) {
        currentMode = slot
        if let modeAudio = modes.first(where: { $0.id == slot })?.audio { audio = modeAudio }
    }

    private func applyConfirmedMode(_ mode: ModeConfiguration) {
        replaceMode(mode)
        guard mode.id == currentMode, profile.noiseControl == .modeConfiguration,
              let modeAudio = mode.audio else { return }
        audio = modeAudio
    }

    private func replaceMode(_ mode: ModeConfiguration) {
        setModes(modes.map { $0.id == mode.id ? mode : $0 })
    }

    @discardableResult
    func perform(refreshing scope: RefreshScope? = nil, settling tickets: [PendingChanges.Ticket] = [],
                 _ action: Action) async -> Bool {
        if actions.isEmpty { error = nil }
        busy = true
        await actions.enter()
        await refreshTask?.task.value
        var succeeded = false
        var failure: (any Error)?
        if connected, let device {
            do {
                if let change = try await action(device) { apply(change) }
                succeeded = true
            } catch {
                failure = error
            }
        }
        tickets.forEach { $0.settle() }
        if let failure {
            await handle(failure)
            deferRefresh(.full)
        } else if succeeded, let scope {
            deferRefresh(scope)
        }
        actions.leave()
        if actions.isEmpty {
            busy = false
            if connected, let deferredRefresh { await refresh(deferredRefresh) }
        }
        return succeeded
    }

    @discardableResult
    func send(refreshing scope: RefreshScope? = nil, pending tickets: [PendingChanges.Ticket] = [],
              _ action: @escaping Action) -> Task<Bool, Never> {
        Task { await perform(refreshing: scope, settling: tickets, action) }
    }

    @discardableResult
    func send<Value>(_ value: Value, pending field: ReferenceWritableKeyPath<PendingChanges, PendingValue<Value>>,
                     refreshing scope: RefreshScope? = nil, _ action: @escaping Action) -> Task<Bool, Never> {
        send(refreshing: scope, pending: [pending.request(value, at: field)], action)
    }

    private func handle(_ error: any Error) async {
        self.error = AppError(error)
        guard Self.dropsConnection(error) else { return }
        failures += 1
        retryAfter = Date().addingTimeInterval(policy.retryDelay(afterFailures: failures))
        await closeConnection()
    }

    private static func dropsConnection(_ error: any Error) -> Bool {
        switch error as? BoseError {
        case .disconnected?, .timeout?, .transport?: true
        default: false
        }
    }
}
