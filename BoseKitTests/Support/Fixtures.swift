import Foundation
import Testing
import BoseKitEngine
@testable import BoseKit

@MainActor
struct HeadsetFixture {
    let headset = FakeHeadset()
    let profile: DeviceProfile
    let controller: DeviceController

    init(features: [FeatureID: FeatureAccess] = [.battery: .read], modePolicy: ModePolicy? = nil) {
        profile = DeviceProfile(id: "test", name: "Test", productIDs: [1], rfcommChannel: 2,
                                features: features, modePolicy: modePolicy)
        controller = DeviceController(id: "test", name: "Test", profile: profile) { [headset] _, profile in
            try await BoseDevice.connect(profile: profile, transport: headset)
        }
    }

    static func withModes() -> HeadsetFixture {
        HeadsetFixture(
            features: [.battery: .read, .modes: .read, .currentMode: .readWrite],
            modePolicy: ModePolicy(codec: StandardModeCodec(.status44), editableSlots: [],
                                   presetSlots: Set(FakeHeadset.modeSlots), expectedSlots: Set(FakeHeadset.modeSlots))
        )
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
