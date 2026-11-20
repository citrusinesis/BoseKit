import Foundation

enum LabelInput {
    static func start(feeding inputs: AsyncStream<MonitorInput>.Continuation) {
        Thread.detachNewThread {
            while let line = readLine() {
                inputs.yield(.label(line.trimmingCharacters(in: .whitespaces)))
            }
            inputs.yield(.labelsEnded)
        }
    }
}
