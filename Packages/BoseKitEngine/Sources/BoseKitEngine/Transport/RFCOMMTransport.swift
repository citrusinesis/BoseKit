import Foundation
@preconcurrency import IOBluetooth

@MainActor
public final class RFCOMMTransport: NSObject, BMAPTransport, @preconcurrency IOBluetoothRFCOMMChannelDelegate {
    private let address: String
    private let channelID: UInt8
    private let closeSettlement: Duration
    private var device: IOBluetoothDevice?
    private var channel: IOBluetoothRFCOMMChannel?
    private var opening: CheckedContinuation<AsyncThrowingStream<[UInt8], any Error>, any Error>?
    private var openTimeout: Task<Void, Never>?
    private let stream: AsyncThrowingStream<[UInt8], any Error>
    private let incoming: AsyncThrowingStream<[UInt8], any Error>.Continuation
    private var used = false
    private var closed = false
    private var closingChannel: IOBluetoothRFCOMMChannel?
    private var closeWaiters: [CheckedContinuation<Void, Never>] = []
    private var closeTimeout: Task<Void, Never>?
    private struct PendingWrite {
        let buffer: NSData
        var continuation: CheckedContinuation<Void, any Error>?
        let timeout: Task<Void, Never>
    }
    private var pendingWrites: [Int: PendingWrite] = [:]
    private var nextWriteID = 1

    public init(address: String, channel: UInt8, closeSettlement: Duration = .milliseconds(150)) {
        self.address = address
        self.channelID = channel
        self.closeSettlement = closeSettlement
        let pair = AsyncThrowingStream<[UInt8], any Error>.makeStream()
        stream = pair.stream
        incoming = pair.continuation
        super.init()
    }

    nonisolated public static func pairedDevices() -> [PairedBluetoothDevice] {
        (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).compactMap { device in
            guard let address = device.addressString else { return nil }
            let record = device.getServiceRecord(for: IOBluetoothSDPUUID(uuid16: 0x1200))
            let vendor = record?.getAttributeDataElement(0x0201)?.getNumberValue()?.uint16Value
            let product = record?.getAttributeDataElement(0x0202)?.getNumberValue()?.uint16Value
            let source = record?.getAttributeDataElement(0x0205)?.getNumberValue()?.uint16Value
            let identity: BluetoothProductIdentity?
            if let vendor, let product, let source {
                identity = BluetoothProductIdentity(vendorIDSource: source, vendorID: vendor, productID: product)
            } else {
                identity = nil
            }
            return PairedBluetoothDevice(id: address, name: device.name ?? address, identity: identity,
                                         isConnected: device.isConnected())
        }
    }

    @MainActor public func open() async throws -> AsyncThrowingStream<[UInt8], any Error> {
        guard !used, !closed else { throw BoseError.disconnected }
        guard (1...30).contains(channelID) else { throw BoseError.invalidArgument("RFCOMM channel must be 1...30") }
        used = true
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                opening = continuation
                guard let device = IOBluetoothDevice(addressString: address) else {
                    terminate(BoseError.invalidArgument("Bluetooth address"))
                    return
                }
                self.device = device
                openTimeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(12)) } catch { return }
                    self?.terminate(BoseError.timeout)
                }
                if device.isConnected() { openChannel() }
                else {
                    let status = device.openConnection(self)
                    if status != kIOReturnSuccess { terminate(BoseError.transport(status)) }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.terminate(CancellationError()) }
        }
    }

    @objc public func connectionComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard !closed, opening != nil else { return }
        if status == kIOReturnSuccess { openChannel() }
        else { terminate(BoseError.transport(status)) }
    }

    private func openChannel() {
        guard let device, !closed else { return }
        let status = device.openRFCOMMChannelAsync(&channel, withChannelID: channelID, delegate: self)
        if status != kIOReturnSuccess { terminate(BoseError.transport(status)) }
    }

    public func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status: IOReturn) {
        guard !closed else {
            _ = rfcommChannel?.close()
            return
        }
        guard status == kIOReturnSuccess else { terminate(BoseError.transport(status)); return }
        channel = rfcommChannel
        openTimeout?.cancel()
        openTimeout = nil
        let continuation = opening
        opening = nil
        continuation?.resume(returning: stream)
    }

    public func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!,
                                  data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        guard !closed, let dataPointer, dataLength > 0 else { return }
        incoming.yield(Array(UnsafeRawBufferPointer(start: dataPointer, count: dataLength)))
    }

    public func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        if closed {
            closeTimeout?.cancel()
            closeTimeout = Task { [weak self, closeSettlement] in
                do { try await Task.sleep(for: closeSettlement) } catch { return }
                self?.finishClosing()
            }
        } else {
            _ = channel?.setDelegate(nil)
            channel = nil
            terminate(BoseError.disconnected)
        }
    }

    @MainActor public func write(_ bytes: [UInt8]) async throws {
        try Task.checkCancellation()
        guard !closed, let channel, channel.isOpen() else { throw BoseError.disconnected }
        guard bytes.count <= 259 else { throw BoseError.invalidArgument("BMAP packet size") }
        let mtu = max(1, Int(channel.getMTU()))
        for offset in stride(from: 0, to: bytes.count, by: mtu) {
            try Task.checkCancellation()
            guard !closed else { throw BoseError.disconnected }
            let buffer = NSData(data: Data(bytes[offset..<min(offset + mtu, bytes.count)]))
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    let identifier = nextWriteID
                    nextWriteID += 1
                    let timeout = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(3)) } catch { return }
                        self?.terminate(BoseError.timeout)
                    }
                    pendingWrites[identifier] = PendingWrite(buffer: buffer, continuation: continuation, timeout: timeout)
                    let status = channel.writeAsync(UnsafeMutableRawPointer(mutating: buffer.bytes),
                                                    length: UInt16(buffer.length),
                                                    refcon: UnsafeMutableRawPointer(bitPattern: identifier))
                    if status != kIOReturnSuccess { terminate(BoseError.transport(status)) }
                }
            } onCancel: {
                Task { @MainActor [weak self] in self?.terminate(CancellationError()) }
            }
        }
    }

    public func rfcommChannelWriteComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!,
                                          refcon: UnsafeMutableRawPointer!, status: IOReturn) {
        let identifier = Int(bitPattern: refcon)
        guard let pending = pendingWrites.removeValue(forKey: identifier) else { return }
        pending.timeout.cancel()
        if status == kIOReturnSuccess { pending.continuation?.resume() }
        else {
            pending.continuation?.resume(throwing: BoseError.transport(status))
            terminate(BoseError.transport(status))
        }
    }

    private func terminate(_ error: any Error) {
        guard !closed else { return }
        closed = true
        for identifier in Array(pendingWrites.keys) {
            pendingWrites[identifier]?.timeout.cancel()
            pendingWrites[identifier]?.continuation?.resume(throwing: error)
            pendingWrites[identifier]?.continuation = nil
        }
        openTimeout?.cancel()
        openTimeout = nil
        let continuation = opening
        opening = nil
        continuation?.resume(throwing: error)
        incoming.finish(throwing: error)
        closingChannel = channel
        channel = nil
        if let closingChannel {
            closeTimeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                self?.finishClosing()
            }
            if closingChannel.close() != kIOReturnSuccess { finishClosing() }
        }
        device = nil
    }

    private func finishClosing() {
        closeTimeout?.cancel()
        closeTimeout = nil
        _ = closingChannel?.setDelegate(nil)
        closingChannel = nil
        pendingWrites.removeAll()
        let waiters = closeWaiters
        closeWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    @MainActor public func close() async {
        terminate(BoseError.disconnected)
        guard closingChannel != nil else { return }
        await withCheckedContinuation { closeWaiters.append($0) }
    }
}
