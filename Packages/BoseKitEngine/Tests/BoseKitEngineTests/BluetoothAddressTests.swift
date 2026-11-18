import Testing
@testable import BoseKitEngine

struct BluetoothAddressTests {
    @Test func parsesColonAndDashSeparators() throws {
        let dashed = try #require(BluetoothAddress(string: "ac-bf-71-0a-1b-2c"))
        let coloned = try #require(BluetoothAddress(string: "AC:BF:71:0A:1B:2C"))
        #expect(dashed.bytes == [0xac, 0xbf, 0x71, 0x0a, 0x1b, 0x2c])
        #expect(dashed == coloned)
    }

    @Test func descriptionIsUppercaseAndZeroPadded() throws {
        let address = try #require(BluetoothAddress(bytes: [0x00, 0x01, 0x0a, 0xab, 0xf0, 0xff]))
        #expect(address.description == "00:01:0A:AB:F0:FF")
    }

    @Test(arguments: [
        "",
        "AC:BF:71:0A:1B",
        "AC:BF:71:0A:1B:2C:3D",
        "AC:BF:71:0A:1B:2",
        "AC:BF:71:0A:1B:2CC",
        "AC:BF:71:0A:1B:ZZ",
        "AC:BF:71:0A:1B:+1",
        "AC:BF:71:0A:1B:",
        "acbf710a1b2c",
        " AC:BF:71:0A:1B:2C",
        "AC:BF:71:0A:1B:２C",
        "AC:BF-71:0A:1B:2C",
        "AC-BF-71-0A-1B:2C",
    ])
    func malformedStringsAreRejected(_ string: String) {
        #expect(BluetoothAddress(string: string) == nil)
    }

    @Test(arguments: [0, 5, 7])
    func byteArraysOfTheWrongLengthAreRejected(_ count: Int) {
        #expect(BluetoothAddress(bytes: Array(repeating: 0, count: count)) == nil)
    }
}
