import Testing
@testable import BoseKitEngine

struct DecodeVector<Value: Equatable & Sendable>: Sendable, CustomTestStringConvertible {
    let name: String
    let product: UInt16
    let payload: [UInt8]
    let expected: Value

    init(_ name: String, product: UInt16 = 0x4066, _ payload: [UInt8], _ expected: Value) {
        self.name = name
        self.product = product
        self.payload = payload
        self.expected = expected
    }

    var testDescription: String { name }
}

struct EncodeVector<Input: Sendable>: Sendable, CustomTestStringConvertible {
    let name: String
    let product: UInt16
    let input: Input
    let expected: [UInt8]

    init(_ name: String, product: UInt16 = 0x4066, _ input: Input, _ expected: [UInt8]) {
        self.name = name
        self.product = product
        self.input = input
        self.expected = expected
    }

    var testDescription: String { name }
}

struct RejectedPayload: Sendable, CustomTestStringConvertible {
    let name: String
    let product: UInt16
    let payload: [UInt8]

    init(_ name: String, product: UInt16 = 0x4066, _ payload: [UInt8]) {
        self.name = name
        self.product = product
        self.payload = payload
    }

    var testDescription: String { name }
}

struct TrailingByteVector: Sendable, CustomTestStringConvertible {
    let name: String
    let minimumLength: Int
    let valid: [UInt8]
    let end: PayloadEnd
    let decodesEqually: @Sendable ([UInt8], [UInt8]) throws -> Bool

    init<Value: Equatable, Input>(_ name: String, _ feature: BoseFeature<Value, Input>, minimumLength: Int,
                                  valid: [UInt8], end: PayloadEnd) {
        self.name = name
        self.minimumLength = minimumLength
        self.valid = valid
        self.end = end
        decodesEqually = { lhs, rhs in
            let profile = try wireProfile()
            return try feature.decode(lhs, profile) == feature.decode(rhs, profile)
        }
    }

    var testDescription: String { name }
}

func isInvalidPayload(_ error: any Error) -> Bool {
    if case BoseError.invalidPayload = error { true } else { false }
}

func isInvalidArgument(_ error: any Error) -> Bool {
    if case BoseError.invalidArgument = error { true } else { false }
}

func expectInvalidPayload<R>(
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () throws -> R
) {
    #expect(sourceLocation: sourceLocation) { try body() } throws: { isInvalidPayload($0) }
}

func expectInvalidArgument<R>(
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () throws -> R
) {
    #expect(sourceLocation: sourceLocation) { try body() } throws: { isInvalidArgument($0) }
}

func zeros(_ count: Int) -> [UInt8] {
    Array(repeating: 0, count: count)
}

func padded(_ bytes: [UInt8], to length: Int) -> [UInt8] {
    bytes + zeros(length - bytes.count)
}

func address(_ string: String) throws -> BluetoothAddress {
    try #require(BluetoothAddress(string: string))
}

func wireProfile(_ productID: UInt16 = 0x4066) throws -> DeviceProfile {
    try #require(DeviceRegistry.standard.profile(productID: productID))
}
