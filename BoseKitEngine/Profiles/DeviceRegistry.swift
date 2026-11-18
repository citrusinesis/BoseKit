public struct DeviceRegistry: Sendable {
    public private(set) var profiles: [DeviceProfile] = []

    public init(profiles: [DeviceProfile] = []) throws {
        for profile in profiles { try register(profile) }
    }

    public mutating func register(_ profile: DeviceProfile) throws {
        for existing in profiles {
            if let duplicate = existing.productIDs.intersection(profile.productIDs).first {
                throw BoseError.duplicateProduct(duplicate)
            }
            guard existing.id != profile.id else { throw BoseError.invalidArgument("Duplicate profile ID") }
        }
        profiles.append(profile)
    }

    public func profile(productID: UInt16) -> DeviceProfile? {
        profiles.first { $0.productIDs.contains(productID) }
    }
}
