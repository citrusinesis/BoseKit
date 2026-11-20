import BoseKitEngine

@MainActor
final class ProbeSession {
    private struct Connection {
        let session: BMAPSession
        let printer: Task<Void, Never>
    }

    private let target: ProbeTarget
    private let profile: DeviceProfile
    private let subscription: NotificationBlocks?
    private let printsReplies: Bool
    private let onEnd: @MainActor @Sendable (Int) -> Void
    private var connection: Connection
    private(set) var generation = 0

    private init(target: ProbeTarget, profile: DeviceProfile, subscription: NotificationBlocks?, printsReplies: Bool,
                 onEnd: @escaping @MainActor @Sendable (Int) -> Void, connection: Connection) {
        self.target = target
        self.profile = profile
        self.subscription = subscription
        self.printsReplies = printsReplies
        self.onEnd = onEnd
        self.connection = connection
    }

    static func open(
        _ target: ProbeTarget, profile: DeviceProfile, subscription: NotificationBlocks?, printsReplies: Bool,
        onEnd: @escaping @MainActor @Sendable (Int) -> Void
    ) async throws -> ProbeSession {
        print("Connecting to \(target.name) (\(profile.id)) on RFCOMM channel \(profile.rfcommChannel.rawValue)")
        let connection = try await connect(target, profile, printsReplies: printsReplies, generation: 0, onEnd: onEnd)
        let probe = ProbeSession(target: target, profile: profile, subscription: subscription,
                                 printsReplies: printsReplies, onEnd: onEnd, connection: connection)
        try await probe.prepare()
        return probe
    }

    func reconnect() async throws {
        generation += 1
        await close()
        print("Reconnecting to \(target.name)")
        connection = try await Self.connect(target, profile, printsReplies: printsReplies,
                                            generation: generation, onEnd: onEnd)
        try await prepare()
    }

    func close() async {
        await connection.session.close()
        await connection.printer.value
    }

    func read(_ address: BMAPAddress, timeout: Duration = .seconds(4)) async throws -> RegisterReply {
        let session = connection.session
        let replies = await session.events()
        let command = BMAPCommand(packet: try BMAPPacket(address: address, operation: .get), timeout: timeout) { $0 }
        do {
            guard let reply = try await session.execute(command).last else {
                throw ProbeError.replyNotObserved(address)
            }
            return .answered(reply.payload)
        } catch BoseError.device {
            return .deviceError(try await errorPayload(for: address, in: replies))
        }
    }

    private static func connect(
        _ target: ProbeTarget, _ profile: DeviceProfile, printsReplies: Bool, generation: Int,
        onEnd: @escaping @MainActor @Sendable (Int) -> Void
    ) async throws -> Connection {
        let transport = RFCOMMTransport(address: target.address, channel: profile.rfcommChannel)
        let session = try await BMAPSession.connect(transport: transport)
        let events = await session.events()
        let printer = Task {
            for await event in events where printsReplies || event.origin == .unsolicited {
                print(EventLine.format(event, time: Timestamp.now()))
            }
            onEnd(generation)
        }
        return Connection(session: session, printer: printer)
    }

    private func prepare() async throws {
        do {
            for packet in profile.initialization {
                _ = try await connection.session.execute(BMAPCommand(packet: packet) { $0 })
            }
            try await reportSubscription()
        } catch {
            await close()
            throw error
        }
    }

    private func reportSubscription() async throws {
        switch try await read(.notifications) {
        case .answered(let bitmap):
            print("Subscribed function blocks: \(try NotificationBlocks(bitmap: bitmap))")
        case .deviceError(let payload):
            print("Reading the notification subscription was rejected (ERROR \(EventLine.hex(payload))).")
        }
        guard let subscription else { return }
        let packet = try BMAPPacket(address: .notifications, operation: .setGet,
                                    payload: subscription.subscriptionPayload)
        guard let reply = try await connection.session.execute(BMAPCommand(packet: packet) { $0 }).last else {
            throw ProbeError.replyNotObserved(.notifications)
        }
        let applied = try NotificationBlocks(bitmap: reply.payload)
        print("Requested function blocks \(subscription); the device reports \(applied)")
    }

    private func errorPayload(for address: BMAPAddress, in replies: AsyncStream<BMAPEvent>) async throws -> [UInt8] {
        for await event in replies
        where event.origin == .reply && event.packet.address == address && event.packet.operation == .error {
            return event.packet.payload
        }
        try Task.checkCancellation()
        throw ProbeError.replyNotObserved(address)
    }
}
