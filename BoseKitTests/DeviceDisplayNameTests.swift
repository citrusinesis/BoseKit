import Testing
@testable import BoseKit

struct DeviceDisplayNameTests {
    private let headphones = "QuietComfort Ultra Headphones"
    private let earbuds = "QuietComfort Ultra Earbuds"

    private func listing(_ id: String, _ name: String, _ model: String) -> DeviceListing {
        DeviceListing(id: id, name: name, model: model)
    }

    @Test func uniqueNamesStayPlain() {
        let names = DeviceListing.displayNames(for: [
            listing("a", "Desk", headphones),
            listing("b", "Travel", earbuds),
        ])
        #expect(names == ["a": "Desk", "b": "Travel"])
    }

    @Test func sameNameDifferentModelAppendsModelOnly() {
        let names = DeviceListing.displayNames(for: [
            listing("a", "Bose", headphones),
            listing("b", "Bose", earbuds),
            listing("c", "Travel", headphones),
        ])
        #expect(names == [
            "a": "Bose — QuietComfort Ultra Headphones",
            "b": "Bose — QuietComfort Ultra Earbuds",
            "c": "Travel",
        ])
    }

    @Test func sameNameAndModelAppendsAddressSuffix() {
        let names = DeviceListing.displayNames(for: [
            listing("ac-bf-71-0a-1b-2c", "Headphones", headphones),
            listing("ac-bf-71-0a-3d-4e", "Headphones", headphones),
            listing("ac-bf-71-0a-5f-60", "Headphones", earbuds),
        ])
        #expect(names == [
            "ac-bf-71-0a-1b-2c": "Headphones — QuietComfort Ultra Headphones (1B2C)",
            "ac-bf-71-0a-3d-4e": "Headphones — QuietComfort Ultra Headphones (3D4E)",
            "ac-bf-71-0a-5f-60": "Headphones — QuietComfort Ultra Earbuds",
        ])
    }

    @Test func suffixIgnoresColonAndDashSeparators() {
        let names = DeviceListing.displayNames(for: [
            listing("AC:BF:71:0A:1b:2c", "Bose", headphones),
            listing("ac-bf-71-0a-3d-4e", "Bose", headphones),
        ])
        #expect(names["AC:BF:71:0A:1b:2c"] == "Bose — QuietComfort Ultra Headphones (1B2C)")
        #expect(names["ac-bf-71-0a-3d-4e"] == "Bose — QuietComfort Ultra Headphones (3D4E)")
    }

    @Test func shortIdsUseAvailableDigits() {
        let names = DeviceListing.displayNames(for: [
            listing("a-b", "Bose", headphones),
            listing("c", "Bose", headphones),
            listing("zz", "Bose", headphones),
        ])
        #expect(names["a-b"] == "Bose — QuietComfort Ultra Headphones (AB)")
        #expect(names["c"] == "Bose — QuietComfort Ultra Headphones (C)")
        #expect(names["zz"] == "Bose — QuietComfort Ultra Headphones")
    }

    @Test func nameComparisonIsExact() {
        let names = DeviceListing.displayNames(for: [
            listing("a", "Bose", headphones),
            listing("b", "bose", headphones),
            listing("c", "Bose ", headphones),
        ])
        #expect(names == ["a": "Bose", "b": "bose", "c": "Bose "])
    }

    @Test func emptyInputYieldsNoNames() {
        #expect(DeviceListing.displayNames(for: []).isEmpty)
    }
}
