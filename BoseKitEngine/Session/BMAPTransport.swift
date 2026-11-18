public protocol BMAPTransport: Sendable {
    func open() async throws -> AsyncThrowingStream<[UInt8], any Error>
    func write(_ bytes: [UInt8]) async throws
    func close() async
}
