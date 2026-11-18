import Testing
@testable import BoseKitEngine

func frame(_ address: BMAPAddress, _ operation: BMAPOperator, _ payload: [UInt8] = []) -> [UInt8] {
    [address.block, address.function, operation.rawValue, UInt8(payload.count)] + payload
}

func query(
    _ address: BMAPAddress = .init(2, 2),
    operation: BMAPOperator = .get,
    timeout: Duration = .seconds(2)
) throws -> BMAPCommand<[UInt8]> {
    BMAPCommand(packet: try BMAPPacket(address: address, operation: operation), timeout: timeout) {
        try #require($0.last).payload
    }
}
