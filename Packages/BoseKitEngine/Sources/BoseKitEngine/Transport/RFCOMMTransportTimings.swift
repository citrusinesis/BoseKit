struct RFCOMMTransportTimings: Sendable {
    static let standardOpenDeadline: Duration = .seconds(12)
    static let standardWriteChunkDeadline: Duration = .seconds(3)
    static let standardCloseFallback: Duration = .seconds(2)

    var openDeadline: Duration
    var writeChunkDeadline: Duration
    var closeFallback: Duration
    var closeSettlement: Duration

    static func standard(closeSettlement: Duration) -> RFCOMMTransportTimings {
        RFCOMMTransportTimings(
            openDeadline: standardOpenDeadline,
            writeChunkDeadline: standardWriteChunkDeadline,
            closeFallback: standardCloseFallback,
            closeSettlement: closeSettlement
        )
    }
}
