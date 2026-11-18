public enum BoseError: Error, Equatable, Sendable {
    case invalidPayload(String)
    case invalidArgument(String)
    case invalidState(String)
    case unsupported(String)
    case device(BMAPAddress, code: UInt8)
    case disconnected
    case timeout
    case transport(Int32)
    case verificationFailed(String)
    case duplicateProduct(UInt16)
}
