import Foundation

enum Timestamp {
    static func now() -> String {
        Date.now.formatted(
            Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)
                .time(includingFractionalSeconds: true)
        )
    }
}
