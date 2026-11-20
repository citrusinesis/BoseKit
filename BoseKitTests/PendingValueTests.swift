import Testing
@testable import BoseKit

struct PendingValueTests {
    @Test func showsTheConfirmedValueWithoutARequest() {
        let value = PendingValue<Int>()
        #expect(!value.isPending)
        #expect(value.shown(over: 1) == 1)
    }

    @Test func showsTheRequestedValueUntilItSettles() {
        var value = PendingValue<Int>()
        let request = value.request(2)
        #expect(value.isPending)
        #expect(value.shown(over: 1) == 2)
        value.settle(request)
        #expect(!value.isPending)
        #expect(value.shown(over: 3) == 3)
    }

    @Test func failedRequestFallsBackToTheUntouchedConfirmedValue() {
        var value = PendingValue<Int>()
        let request = value.request(2)
        value.settle(request)
        #expect(value.shown(over: 1) == 1)
    }

    @Test func earlierRequestSettlingKeepsTheNewerValue() {
        var value = PendingValue<Int>()
        let first = value.request(2)
        let second = value.request(3)
        value.settle(first)
        #expect(value.shown(over: 2) == 3)
        value.settle(second)
        #expect(value.shown(over: 3) == 3)
        #expect(!value.isPending)
    }

    @Test func newerRequestFailingFallsBackToTheEarlierConfirmation() {
        var value = PendingValue<Int>()
        let first = value.request(2)
        let second = value.request(3)
        value.settle(first)
        value.settle(second)
        #expect(value.shown(over: 2) == 2)
    }

    @Test func clearDropsThePendingValue() {
        var value = PendingValue<Int>()
        _ = value.request(2)
        value.clear()
        #expect(!value.isPending)
        #expect(value.shown(over: 1) == 1)
    }

    @Test func requestFromBeforeAClearDoesNotClearALaterRequest() {
        var value = PendingValue<Int>()
        let stale = value.request(2)
        value.clear()
        _ = value.request(3)
        value.settle(stale)
        #expect(value.shown(over: 1) == 3)
    }

    @Test func tableKeepsEachKeyIndependent() {
        var table = PendingTable<UInt8, Int>()
        let first = table[1].request(10)
        _ = table[2].request(20)
        table[1].settle(first)
        #expect(table[1].shown(over: 1) == 1)
        #expect(table[2].shown(over: 2) == 20)
        #expect(table.isPending)
        table.clear()
        #expect(!table.isPending)
        #expect(table[2].shown(over: 2) == 2)
    }

    @Test func tableRequestFromBeforeAClearDoesNotClearALaterRequest() {
        var table = PendingTable<UInt8, Int>()
        let stale = table[1].request(10)
        table.clear()
        _ = table[1].request(11)
        table[1].settle(stale)
        #expect(table[1].shown(over: 1) == 11)
    }
}
