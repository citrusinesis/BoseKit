public struct BoseFeature<Value: Sendable, Input: Sendable>: Sendable {
    public let id: FeatureID
    public let address: BMAPAddress
    public let writeOperation: BMAPOperator
    let decode: @Sendable ([UInt8], DeviceProfile) throws -> Value
    private let encoder: (@Sendable (Input, DeviceProfile) throws -> [UInt8])?

    public init(id: FeatureID, address: BMAPAddress, writeOperation: BMAPOperator = .setGet,
                decode: @escaping @Sendable ([UInt8], DeviceProfile) throws -> Value,
                encode: @escaping @Sendable (Input, DeviceProfile) throws -> [UInt8]) {
        self.id = id
        self.address = address
        self.writeOperation = writeOperation
        self.decode = decode
        self.encoder = encode
    }

    public init(id: FeatureID, address: BMAPAddress,
                decode: @escaping @Sendable ([UInt8], DeviceProfile) throws -> Value) where Input == Never {
        self.id = id
        self.address = address
        self.writeOperation = .setGet
        self.decode = decode
        self.encoder = nil
    }

    func encode(_ input: Input, _ profile: DeviceProfile) throws -> [UInt8] {
        guard let encoder else { throw BoseError.unsupported(id.rawValue) }
        return try encoder(input, profile)
    }
}
