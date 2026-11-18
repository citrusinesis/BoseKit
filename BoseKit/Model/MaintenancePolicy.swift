import Foundation

struct MaintenancePolicy: Sendable {
    var discoveryInterval: Duration = .seconds(5)
    var fullRefreshInterval: TimeInterval = 30
    var idleProbeInterval: TimeInterval = 30
    var maximumRetryDelay: TimeInterval = 60

    func retryDelay(afterFailures failures: Int) -> TimeInterval {
        min(maximumRetryDelay, pow(2, Double(min(failures, 5))))
    }

    static let standard = MaintenancePolicy()
}
