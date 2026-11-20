nonisolated struct DeviceListing: Equatable {
    let id: String
    let name: String
    let model: String

    private static let separator = " — "
    private static let suffixLength = 4

    static func displayNames(for listings: [DeviceListing]) -> [String: String] {
        let nameCounts = listings.reduce(into: [String: Int]()) { $0[$1.name, default: 0] += 1 }
        let identityCounts = listings.reduce(into: [Identity: Int]()) { $0[Identity($1), default: 0] += 1 }
        var result: [String: String] = [:]
        for listing in listings {
            guard nameCounts[listing.name, default: 0] > 1 else {
                result[listing.id] = listing.name
                continue
            }
            let qualified = listing.name + separator + listing.model
            guard identityCounts[Identity(listing), default: 0] > 1 else {
                result[listing.id] = qualified
                continue
            }
            let suffix = addressSuffix(of: listing.id)
            result[listing.id] = suffix.isEmpty ? qualified : "\(qualified) (\(suffix))"
        }
        return result
    }

    private static func addressSuffix(of id: String) -> String {
        String(id.filter { $0.isASCII && $0.isHexDigit }.suffix(suffixLength)).uppercased()
    }

    private struct Identity: Hashable {
        let name: String
        let model: String

        init(_ listing: DeviceListing) {
            name = listing.name
            model = listing.model
        }
    }
}
