struct PayloadWriter {
    private var bytes: [UInt8] = []

    private init() {}

    static func build(_ body: (inout PayloadWriter) throws -> Void) rethrows -> [UInt8] {
        var writer = PayloadWriter()
        try body(&writer)
        return writer.bytes
    }

    mutating func u8(_ value: UInt8) {
        bytes.append(value)
    }

    mutating func u16(_ value: UInt16) {
        bytes += [UInt8(value >> 8), UInt8(value & 0xff)]
    }

    mutating func bool(_ value: Bool) {
        bytes.append(value ? 1 : 0)
    }

    mutating func append(_ value: [UInt8]) {
        bytes += value
    }

    mutating func nulPadded(_ value: [UInt8], fieldLength: Int) {
        precondition(value.count <= fieldLength, "Field holds at most \(fieldLength) bytes")
        bytes += value + Array(repeating: 0, count: fieldLength - value.count)
    }
}
