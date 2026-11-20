import BoseKitEngine

enum MonitorInput: Sendable {
    case label(String)
    case labelsEnded
    case connectionEnded(generation: Int)
}

@MainActor
enum Monitor {
    private enum End {
        case interrupted
        case connectionLost
    }

    static func run(_ target: ProbeTarget, profile: DeviceProfile, options: MonitorOptions) async throws {
        let (inputs, continuation) = AsyncStream<MonitorInput>.makeStream()
        let probe: ProbeSession
        do {
            probe = try await ProbeSession.open(
                target, profile: profile, subscription: options.subscription, printsReplies: options.snapshots == nil
            ) { continuation.yield(.connectionEnded(generation: $0)) }
        } catch is CancellationError {
            print("Stopped.")
            return
        }
        let end: End
        do {
            end = try await watch(inputs, feeding: continuation, probe: probe, snapshots: options.snapshots)
        } catch {
            await probe.close()
            throw error
        }
        await probe.close()
        switch end {
        case .interrupted: print("Stopped.")
        case .connectionLost: throw ProbeError.connectionLost
        }
    }

    private static func watch(
        _ inputs: AsyncStream<MonitorInput>, feeding continuation: AsyncStream<MonitorInput>.Continuation,
        probe: ProbeSession, snapshots: SnapshotOptions?
    ) async throws -> End {
        var recorder = snapshots.map(SnapshotRecorder.init)
        if recorder == nil {
            print("Monitoring. Press Control-C to stop.")
        } else {
            LabelInput.start(feeding: continuation)
            print("Monitoring. Type a label and press Return to take a snapshot; press Control-C to stop.")
        }
        do {
            for await input in inputs {
                switch input {
                case .label(let label):
                    try await recorder?.take(label: label, on: probe)
                case .labelsEnded:
                    print("Standard input ended, so no more snapshots can be taken. Monitoring continues until Control-C.")
                case .connectionEnded(let generation) where generation == probe.generation:
                    return .connectionLost
                case .connectionEnded:
                    continue
                }
            }
        } catch is CancellationError {
            return .interrupted
        }
        return .interrupted
    }
}
