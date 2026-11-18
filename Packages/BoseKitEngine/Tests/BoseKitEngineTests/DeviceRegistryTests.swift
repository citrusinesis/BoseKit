import Testing
@testable import BoseKitEngine

struct DeviceRegistryTests {
    private static let expectedProducts: [(UInt16, String)] = [
        (0x400c, "qc35"), (0x4020, "qc35"), (0x4082, "wolverine"), (0x4083, "wolverine"), (0x4062, "edith"),
        (0x4075, "prince"), (0x4039, "duran"), (0x402f, "lando"), (0x4068, "serena"), (0x4024, "goodyear"),
        (0x4066, "lonestarr"),
    ]

    @Test func lookupByEachProductIDReturnsTheNamedProfile() {
        for (productID, profileID) in Self.expectedProducts {
            #expect(DeviceRegistry.standard.profile(productID: productID)?.id == profileID)
        }
        #expect(DeviceRegistry.standard.profile(productID: 0xffff) == nil)
    }

    @Test func standardRegistryContainsExactlyTheNamedProfiles() {
        let named: [DeviceProfile] = [.qc35, .wolverine, .edith, .prince, .duran, .lando, .serena, .goodyear, .lonestarr]
        #expect(DeviceRegistry.standard.profiles.map(\.id) == named.map(\.id))
        #expect(ProfileShape.standard.map(\.id) == named.map(\.id))
        #expect(Set(DeviceRegistry.standard.profiles.flatMap(\.productIDs)) == Set(Self.expectedProducts.map(\.0)))
    }

    @Test func standardProfilesHaveUniqueProductIDs() {
        let productIDs = DeviceRegistry.standard.profiles.flatMap(\.productIDs)
        #expect(Set(productIDs).count == productIDs.count)
    }

    @Test func standardProfilesHaveUniqueProfileIDs() {
        let ids = DeviceRegistry.standard.profiles.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func standardProfilesRoundTripThroughCheckedRegistration() throws {
        let checked = try DeviceRegistry(profiles: DeviceRegistry.standard.profiles)
        #expect(checked.profiles.map(\.id) == DeviceRegistry.standard.profiles.map(\.id))
    }

    @Test(arguments: ProfileShape.standard)
    func namedProfileMatchesCapturedShape(_ expected: ProfileShape) throws {
        let profile = try #require(DeviceRegistry.standard.profiles.first { $0.id == expected.id })
        #expect(ProfileShape(profile) == expected)
    }

    @Test func registrationRejectsDuplicateProductID() {
        var registry = DeviceRegistry.standard
        #expect(throws: BoseError.duplicateProduct(0x4066)) { try registry.register(.lonestarr) }
    }

    @Test func registrationRejectsDuplicateProfileID() {
        var registry = DeviceRegistry.standard
        let renamed = DeviceProfile(id: "lonestarr", name: "Copy", productIDs: [0xfffe], rfcommChannel: 2, features: [:])
        #expect(throws: BoseError.duplicateProfile("lonestarr")) { try registry.register(renamed) }
    }

    @Test func checkedInitializerRejectsDuplicates() {
        #expect(throws: BoseError.duplicateProduct(0x4066)) {
            try DeviceRegistry(profiles: [.lonestarr, .lonestarr])
        }
    }
}
