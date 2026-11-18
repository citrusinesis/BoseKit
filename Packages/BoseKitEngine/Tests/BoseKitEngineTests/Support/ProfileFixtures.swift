import Testing
@testable import BoseKitEngine

func connectedDevice(
    on transport: some BMAPTransport,
    profile: DeviceProfile = .lonestarr
) async throws -> BoseDevice {
    try await BoseDevice.connect(profile: profile, transport: transport)
}
