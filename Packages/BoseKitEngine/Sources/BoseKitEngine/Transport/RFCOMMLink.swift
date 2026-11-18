typealias RFCOMMEventSink = @MainActor (RFCOMMEvent) -> Void

enum RFCOMMEvent {
    case basebandConnected(Result<Void, BoseError>)
    case channelOpened(Result<Void, BoseError>)
    case received([UInt8])
    case writeCompleted(RFCOMMWriteID, Result<Void, BoseError>)
    case channelClosed
}

struct RFCOMMWriteID: Hashable {
    static let first = RFCOMMWriteID(rawValue: 1)

    let rawValue: Int

    func successor() -> RFCOMMWriteID { RFCOMMWriteID(rawValue: rawValue + 1) }
}

enum BasebandConnection {
    case established
    case pending
}

enum ChannelCloseOutcome {
    case awaitingClosedNotification
    case completed
}

@MainActor
protocol RFCOMMLink: AnyObject {
    func connect(reportingTo sink: @escaping RFCOMMEventSink) throws(BoseError) -> BasebandConnection
    func openChannel(_ channel: RFCOMMChannel, reportingTo sink: @escaping RFCOMMEventSink) throws(BoseError) -> any RFCOMMChannelHandle
}

@MainActor
protocol RFCOMMChannelHandle: AnyObject {
    var maximumTransmissionUnit: Int { get }
    var isOpen: Bool { get }
    func write(_ chunk: ArraySlice<UInt8>, identifier: RFCOMMWriteID) throws(BoseError)
    func close() -> ChannelCloseOutcome
    func detach()
}
