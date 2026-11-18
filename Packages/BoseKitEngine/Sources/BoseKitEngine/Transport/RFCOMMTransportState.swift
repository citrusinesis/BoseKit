enum RFCOMMTransportState {
    typealias OpenContinuation = CheckedContinuation<AsyncThrowingStream<[UInt8], any Error>, any Error>

    struct Connecting {
        enum Step {
            case awaitingBaseband
            case awaitingChannel(any RFCOMMChannelHandle)
        }

        var step: Step
        let continuation: OpenContinuation
        let deadline: Task<Void, Never>
    }

    struct PendingWrite {
        let continuation: CheckedContinuation<Void, any Error>
        let deadline: Task<Void, Never>
    }

    struct Open {
        let channel: any RFCOMMChannelHandle
        var pendingWrites: [RFCOMMWriteID: PendingWrite] = [:]
        var nextWriteID = RFCOMMWriteID.first

        mutating func register(_ continuation: CheckedContinuation<Void, any Error>,
                               deadline: (RFCOMMWriteID) -> Task<Void, Never>) -> RFCOMMWriteID {
            let identifier = nextWriteID
            nextWriteID = identifier.successor()
            pendingWrites[identifier] = PendingWrite(continuation: continuation, deadline: deadline(identifier))
            return identifier
        }
    }

    struct Closing {
        enum Phase {
            case awaitingClosedNotification(fallback: Task<Void, Never>)
            case settling(Task<Void, Never>)

            var timer: Task<Void, Never> {
                switch self {
                case .awaitingClosedNotification(let fallback): fallback
                case .settling(let settlement): settlement
                }
            }
        }

        let channel: any RFCOMMChannelHandle
        var phase: Phase
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    case idle
    case connecting(Connecting)
    case open(Open)
    case closing(Closing)
    case closed
}
