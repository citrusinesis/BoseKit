public struct BoseFeature<Value: Sendable, Input: Sendable>: Sendable {
    private struct Writer: Sendable {
        let encode: @Sendable (Input, DeviceProfile) throws -> [UInt8]
        let confirm: @Sendable (Value, Input) -> Bool
    }

    public let id: FeatureID
    public let address: BMAPAddress
    public let writeOperation: BMAPOperator
    let decode: @Sendable ([UInt8], DeviceProfile) throws -> Value
    private let writer: Writer?

    public init(id: FeatureID, address: BMAPAddress, writeOperation: BMAPOperator = .setGet,
                decode: @escaping @Sendable ([UInt8], DeviceProfile) throws -> Value,
                encode: @escaping @Sendable (Input, DeviceProfile) throws -> [UInt8],
                confirm: @escaping @Sendable (Value, Input) -> Bool) {
        self.id = id
        self.address = address
        self.writeOperation = writeOperation
        self.decode = decode
        self.writer = Writer(encode: encode, confirm: confirm)
    }

    public init(id: FeatureID, address: BMAPAddress,
                decode: @escaping @Sendable ([UInt8], DeviceProfile) throws -> Value) where Input == Never {
        self.id = id
        self.address = address
        self.writeOperation = .setGet
        self.decode = decode
        self.writer = nil
    }

    func encode(_ input: Input, _ profile: DeviceProfile) throws -> [UInt8] {
        try requireWriter().encode(input, profile)
    }

    func confirms(_ value: Value, _ input: Input) throws -> Bool {
        try requireWriter().confirm(value, input)
    }

    private func requireWriter() throws -> Writer {
        guard let writer else { throw BoseError.unsupported(.feature(id)) }
        return writer
    }
}
