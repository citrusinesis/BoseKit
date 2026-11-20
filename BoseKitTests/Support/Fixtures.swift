import Foundation
import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct HeadsetFixture {
    let headset = FakeHeadset()
    let profile: DeviceProfile
    let controller: DeviceController

    init(features: [FeatureID: FeatureAccess] = [.battery: .read], noiseControl: NoiseControlStrategy = .unavailable,
         modePolicy: ModePolicy? = nil) {
        profile = Self.profile(features: features, noiseControl: noiseControl, modePolicy: modePolicy)
        controller = DeviceController(id: "test", name: "Test", profile: profile) { [headset] _, profile in
            try await BoseDevice.connect(profile: profile, transport: headset)
        }
    }

    static func profile(features: [FeatureID: FeatureAccess] = [.battery: .read],
                        noiseControl: NoiseControlStrategy = .unavailable,
                        modePolicy: ModePolicy? = nil) -> DeviceProfile {
        DeviceProfile(id: "test", name: "Test", productIDs: [1], rfcommChannel: 2,
                      features: features, noiseControl: noiseControl, modePolicy: modePolicy)
    }

    static func withModes() -> HeadsetFixture {
        HeadsetFixture(
            features: [.battery: .read, .modes: .read, .currentMode: .readWrite],
            modePolicy: ModePolicy(codec: StandardModeCodec(.status44), editableSlots: [],
                                   presetSlots: Set(FakeModeTable.slots), expectedSlots: Set(FakeModeTable.slots))
        )
    }

    static func withEditableModes() async -> HeadsetFixture {
        let fixture = HeadsetFixture(
            features: [.battery: .read, .modes: .readWrite, .currentMode: .readWrite, .windBlock: .readWrite],
            noiseControl: .modeConfiguration,
            modePolicy: ModePolicy(codec: StandardModeCodec(.status47), editableSlots: FakeModeTable.editableSlots,
                                   presetSlots: [0, 1], windForcesMaximumANC: true)
        )
        await fixture.headset.useModes(FakeModeTable(.editable))
        await fixture.headset.setCurrentMode(2)
        return fixture
    }

    func requestCount() async -> Int { await headset.requests.count }

    func settle(_ command: () -> Void, holding address: BMAPAddress, _ operation: BMAPOperator) async {
        await headset.holdNext(address, operation)
        command()
        await headset.waitUntilHeld()
        let barrier = Task { await controller.perform { _ in nil } }
        await headset.release()
        #expect(await barrier.value)
    }
}

@MainActor
func until(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
    for _ in 0..<10_000 {
        if condition() { return }
        await Task.yield()
    }
    Issue.record("Condition was never met", sourceLocation: sourceLocation)
}

actor Gate {
    private var entered = false
    private var opened = false
    private var enterWaiters: [CheckedContinuation<Void, Never>] = []
    private var openWaiters: [CheckedContinuation<Void, Never>] = []

    func pass() async {
        entered = true
        enterWaiters.forEach { $0.resume() }
        enterWaiters = []
        guard !opened else { return }
        await withCheckedContinuation { openWaiters.append($0) }
    }

    func waitUntilEntered() async {
        guard !entered else { return }
        await withCheckedContinuation { enterWaiters.append($0) }
    }

    func open() {
        opened = true
        openWaiters.forEach { $0.resume() }
        openWaiters = []
    }
}

func isolatedDefaults(_ test: String = #function) throws -> UserDefaults {
    let name = "BoseKitTests." + test.filter { $0.isLetter || $0.isNumber }
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return defaults
}
