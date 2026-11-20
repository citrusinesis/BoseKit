public actor BoseDevice {
    public nonisolated let profile: DeviceProfile
    let session: BMAPSession
    private var transactionActive = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    var rememberedCNC: [UInt8: CNCLevel] = [:]
    var knownModes: [ModeConfiguration]?

    private init(profile: DeviceProfile, session: BMAPSession) {
        self.profile = profile
        self.session = session
    }

    public static func connect(profile: DeviceProfile, transport: any BMAPTransport) async throws -> BoseDevice {
        let session = try await BMAPSession.connect(transport: transport)
        do {
            for packet in profile.initialization {
                _ = try await session.execute(BMAPCommand(packet: packet, decode: { $0 }))
            }
            return BoseDevice(profile: profile, session: session)
        } catch {
            await session.close()
            throw error
        }
    }

    public func events() async -> AsyncStream<BMAPEvent> { await session.events() }
    public func close() async { await session.close() }

    public func read<V, I>(_ feature: BoseFeature<V, I>) async throws -> V {
        try await transaction { device in try await device.readValue(feature) }
    }

    @discardableResult
    public func write<V, I>(_ feature: BoseFeature<V, I>, value: I) async throws -> V {
        try await transaction { device in try await device.writeValue(feature, value) }
    }

    func transaction<T: Sendable>(
        _ body: (isolated BoseDevice) async throws -> T
    ) async throws -> T {
        if transactionActive {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            transactionActive = true
        }
        defer {
            if waiters.isEmpty { transactionActive = false }
            else { waiters.removeFirst().resume() }
        }
        try Task.checkCancellation()
        return try await body(self)
    }

    func check(_ id: FeatureID, _ access: FeatureAccess) throws {
        guard profile.supports(id, access: access) else { throw BoseError.unsupported(.feature(id)) }
    }

    func payload(_ address: BMAPAddress, operation: BMAPOperator = .get,
                 bytes: [UInt8] = []) async throws -> [UInt8] {
        let packet = try BMAPPacket(address: address, operation: operation, payload: bytes)
        return try await session.execute(BMAPCommand(packet: packet) { packets in
            guard let reply = packets.last else { throw BoseError.invalidPayload("Missing reply") }
            return reply.payload
        })
    }

    func readValue<V, I>(_ feature: BoseFeature<V, I>) async throws -> V {
        try check(feature.id, .read)
        return try feature.decode(await payload(feature.address), profile)
    }

    func writeValue<V, I>(_ feature: BoseFeature<V, I>, _ value: I) async throws -> V {
        try check(feature.id, .write)
        let bytes = try feature.encode(value, profile)
        _ = try await payload(feature.address, operation: feature.writeOperation, bytes: bytes)
        let actual = try await readValue(feature)
        guard try feature.confirms(actual, value) else { throw BoseError.verificationFailed(.feature(feature.id)) }
        return actual
    }
}
