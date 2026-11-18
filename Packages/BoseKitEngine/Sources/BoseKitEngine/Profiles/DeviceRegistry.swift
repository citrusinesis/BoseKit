public struct DeviceRegistry: Sendable {
    public private(set) var profiles: [DeviceProfile] = []

    public init(profiles: [DeviceProfile] = []) throws {
        for profile in profiles { try register(profile) }
    }

    init(uncheckedProfiles profiles: [DeviceProfile]) {
        self.profiles = profiles
    }

    public mutating func register(_ profile: DeviceProfile) throws {
        for existing in profiles {
            if let duplicate = existing.productIDs.intersection(profile.productIDs).first {
                throw BoseError.duplicateProduct(duplicate)
            }
            guard existing.id != profile.id else { throw BoseError.duplicateProfile(profile.id) }
        }
        profiles.append(profile)
    }

    public func profile(productID: UInt16) -> DeviceProfile? {
        profiles.first { $0.productIDs.contains(productID) }
    }
}
