import Testing
import BoseKitEngine

struct BMAPErrorCodeTests {
    @Test(arguments: [
        (UInt8(0x00), "Unknown"), (0x01, "Length"), (0x02, "Chksum"), (0x03, "FblockNotSupp"),
        (0x04, "FuncNotSupp"), (0x05, "OpNotSupp"), (0x06, "InvalidData"), (0x07, "DataUnavailable"),
        (0x08, "Runtime"), (0x09, "Timeout"), (0x0A, "InvalidState"), (0x0B, "DeviceNotFound"),
        (0x0C, "Busy"), (0xFF, "FblockSpecific"),
    ])
    func knownCodesAreNamed(_ raw: UInt8, _ name: String) {
        #expect(BMAPErrorCode(rawValue: raw).name == name)
    }

    @Test func unknownCodeKeepsItsRawValueAndHasNoName() {
        let code = BMAPErrorCode(rawValue: 0x42)
        #expect(code.rawValue == 0x42)
        #expect(code.name == nil)
        #expect(code.disposition == .indeterminate)
        #expect(code.description == "0x42")
    }

    @Test func descriptionPadsHexAndAppendsTheName() {
        #expect(BMAPErrorCode.busy.description == "0x0C Busy")
        #expect(BMAPErrorCode.functionBlockSpecific.description == "0xFF FblockSpecific")
    }

    @Test func dispositionTable() {
        let permanent: Set<UInt8> = [0x03, 0x04, 0x05]
        let transient: Set<UInt8> = [0x07, 0x08, 0x09, 0x0A, 0x0C]
        for raw in UInt8.min...UInt8.max {
            let expected: BMAPErrorCode.Disposition =
                permanent.contains(raw) ? .permanent : transient.contains(raw) ? .transient : .indeterminate
            #expect(BMAPErrorCode(rawValue: raw).disposition == expected, "code \(raw)")
        }
    }
}
