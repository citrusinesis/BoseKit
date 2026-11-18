import Foundation
import BoseKitEngine

/// A failure kept for display; the message is localized when a view renders it, not when the error is caught.
enum AppError: Error, Equatable {
    case engine(BoseError)
    /// A non-engine error (for example cancellation from the OS transport), kept as the system's own description.
    case unexpected(String)

    init(_ error: any Error) {
        if let error = error as? BoseError {
            self = .engine(error)
        } else {
            self = .unexpected(error.localizedDescription)
        }
    }
}
