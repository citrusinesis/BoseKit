import Testing
@testable import BoseKitProbe

struct NotificationBlocksTests {
    @Test func officialAppSubscriptionForNC700EncodesToItsCapturedPayload() throws {
        let blocks = try NotificationBlocks(blocks: [0, 1, 2, 4, 5, 9, 16, 18])
        #expect(blocks.subscriptionPayload == [0x01, 0x00, 0x05, 0x02, 0x37])
    }

    @Test func bitmapIsBigEndianWithBlockThirtyOneInTheFirstByte() throws {
        #expect(try NotificationBlocks(blocks: [31]).bitmap == [0x80, 0x00, 0x00, 0x00])
        #expect(try NotificationBlocks(blocks: [0]).bitmap == [0x00, 0x00, 0x00, 0x01])
    }

    @Test func deviceBitmapDecodesBackToTheSameBlocks() throws {
        let blocks = try NotificationBlocks(bitmap: [0x80, 0x05, 0x02, 0x37])
        #expect(blocks.blocks == [0, 1, 2, 4, 5, 9, 16, 18, 31])
        #expect(try NotificationBlocks(bitmap: blocks.bitmap) == blocks)
    }

    @Test func clearedSubscriptionIsAllZeroes() throws {
        let none = try NotificationBlocks(list: "none")
        #expect(none.blocks.isEmpty)
        #expect(none.subscriptionPayload == [0x01, 0, 0, 0, 0])
        #expect(none.description == "none")
    }

    @Test func listParsesCommaSeparatedBlocks() throws {
        let blocks = try NotificationBlocks(list: "31,1,2")
        #expect(blocks.blocks == [1, 2, 31])
        #expect(blocks.description == "1,2,31")
    }

    @Test(arguments: ["32", "1,,2", "a", "", "1, 2", "-1"])
    func malformedListsAreRejected(_ list: String) {
        #expect(throws: ProbeError.self) { try NotificationBlocks(list: list) }
    }

    @Test(arguments: [[], [0, 0, 0], [0, 0, 0, 0, 0]] as [[UInt8]])
    func bitmapsOfTheWrongLengthAreRejected(_ bitmap: [UInt8]) {
        #expect(throws: ProbeError.malformedNotificationState(bitmap)) { try NotificationBlocks(bitmap: bitmap) }
    }
}
