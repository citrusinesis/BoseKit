import Foundation
@preconcurrency import IOBluetooth

@MainActor
final class IOBluetoothRFCOMMLink: NSObject, RFCOMMLink {
    private let device: Result<IOBluetoothDevice, BoseError>
    private var pendingBasebandSink: RFCOMMEventSink?

    init(address: String) {
        if let device = IOBluetoothDevice(addressString: address) {
            self.device = .success(device)
        } else {
            self.device = .failure(BoseError.invalidArgument("Bluetooth address"))
        }
        super.init()
    }

    func connect(reportingTo sink: @escaping RFCOMMEventSink) throws(BoseError) -> BasebandConnection {
        let device = try device.get()
        if device.isConnected() { return .established }
        pendingBasebandSink = sink
        let status = device.openConnection(self)
        guard status == kIOReturnSuccess else {
            pendingBasebandSink = nil
            throw BoseError.transport(status)
        }
        return .pending
    }

    @objc func connectionComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard let sink = pendingBasebandSink else { return }
        pendingBasebandSink = nil
        sink(.basebandConnected(Result(status: status)))
    }

    func openChannel(_ rfcommChannel: RFCOMMChannel, reportingTo sink: @escaping RFCOMMEventSink) throws(BoseError) -> any RFCOMMChannelHandle {
        let device = try device.get()
        let delegate = IOBluetoothRFCOMMChannelDelegateAdapter(sink: sink)
        var channel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelAsync(&channel, withChannelID: rfcommChannel.rawValue, delegate: delegate)
        guard status == kIOReturnSuccess else { throw BoseError.transport(status) }
        guard let channel else { throw BoseError.transport(kIOReturnError) }
        return IOBluetoothRFCOMMChannelHandle(channel: channel, delegate: delegate)
    }
}

@MainActor
private final class IOBluetoothRFCOMMChannelHandle: RFCOMMChannelHandle {
    private let channel: IOBluetoothRFCOMMChannel
    private let delegate: IOBluetoothRFCOMMChannelDelegateAdapter

    init(channel: IOBluetoothRFCOMMChannel, delegate: IOBluetoothRFCOMMChannelDelegateAdapter) {
        self.channel = channel
        self.delegate = delegate
    }

    var maximumTransmissionUnit: Int { Int(channel.getMTU()) }

    var isOpen: Bool { channel.isOpen() }

    func write(_ chunk: ArraySlice<UInt8>, identifier: RFCOMMWriteID) throws(BoseError) {
        guard let length = UInt16(exactly: chunk.count) else {
            throw BoseError.invalidArgument("RFCOMM chunk length")
        }
        let buffer = NSData(data: Data(chunk))
        delegate.retain(buffer, until: identifier)
        let status = channel.writeAsync(UnsafeMutableRawPointer(mutating: buffer.bytes), length: length,
                                        refcon: identifier.refcon)
        guard status == kIOReturnSuccess else {
            delegate.release(identifier)
            throw BoseError.transport(status)
        }
    }

    func close() -> ChannelCloseOutcome {
        channel.close() == kIOReturnSuccess ? .awaitingClosedNotification : .completed
    }

    func detach() {
        _ = channel.setDelegate(nil)
        delegate.releaseAll()
    }
}

@MainActor
private final class IOBluetoothRFCOMMChannelDelegateAdapter: NSObject, @preconcurrency IOBluetoothRFCOMMChannelDelegate {
    private let sink: RFCOMMEventSink
    private var buffersAwaitingCompletion: [RFCOMMWriteID: NSData] = [:]

    init(sink: @escaping RFCOMMEventSink) {
        self.sink = sink
        super.init()
    }

    func retain(_ buffer: NSData, until identifier: RFCOMMWriteID) {
        buffersAwaitingCompletion[identifier] = buffer
    }

    func release(_ identifier: RFCOMMWriteID) {
        buffersAwaitingCompletion[identifier] = nil
    }

    func releaseAll() {
        buffersAwaitingCompletion.removeAll()
    }

    func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status: IOReturn) {
        sink(.channelOpened(Result(status: status)))
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!,
                           data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        guard let dataPointer, dataLength > 0 else { return }
        sink(.received(Array(UnsafeRawBufferPointer(start: dataPointer, count: dataLength))))
    }

    func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!,
                                    refcon: UnsafeMutableRawPointer!, status: IOReturn) {
        let identifier = RFCOMMWriteID(refcon: refcon)
        release(identifier)
        sink(.writeCompleted(identifier, Result(status: status)))
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        sink(.channelClosed)
    }
}

private extension RFCOMMWriteID {
    init(refcon: UnsafeMutableRawPointer?) {
        self.init(rawValue: Int(bitPattern: refcon))
    }

    var refcon: UnsafeMutableRawPointer? { UnsafeMutableRawPointer(bitPattern: rawValue) }
}

private extension Result where Success == Void, Failure == BoseError {
    init(status: IOReturn) {
        self = status == kIOReturnSuccess ? .success(()) : .failure(BoseError.transport(status))
    }
}
