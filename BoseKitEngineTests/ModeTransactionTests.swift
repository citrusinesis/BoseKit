import Foundation
import Testing
@testable import BoseKitEngine

private actor ModeTransport: BMAPTransport {
    private let stream: AsyncThrowingStream<[UInt8], any Error>
    private let sink: AsyncThrowingStream<[UInt8], any Error>.Continuation
    private var slots: [[UInt8]]
    private var currentSlot: UInt8 = 3
    private(set) var writes: [[UInt8]] = []
    private let corruptReadBack: Bool

    init(corruptReadBack: Bool = false) {
        self.corruptReadBack = corruptReadBack
        let pair = AsyncThrowingStream<[UInt8], any Error>.makeStream()
        stream = pair.stream
        sink = pair.continuation
        slots = (0..<10).map { index in
            var bytes = [UInt8](repeating: 0, count: 47)
            bytes[0] = UInt8(index)
            bytes[3] = index >= 3 ? 1 : 0
            bytes[4] = index == 3 ? 1 : 0
            bytes[6] = 88
            bytes[42] = index == 3 ? 7 : 10
            return bytes
        }
    }

    func open() -> AsyncThrowingStream<[UInt8], any Error> { stream }
    func close() { sink.finish() }

    func write(_ bytes: [UInt8]) throws {
        writes.append(bytes)
        if bytes[0] == 31 && bytes[1] == 1 {
            var response: [UInt8] = [31, 1, 7, 0]
            for slot in slots { response += [31, 6, 3, 47] + slot }
            response += [31, 1, 6, 0]
            sink.yield(response)
        } else if bytes[0] == 31 && bytes[1] == 3 {
            if bytes[2] == 5 {
                currentSlot = bytes[4]
                sink.yield([31, 3, 7, 0, 31, 3, 6, 1, currentSlot])
            } else {
                sink.yield([31, 3, 3, 1, currentSlot])
            }
        } else if bytes[0] == 31 && bytes[1] == 6 && bytes[2] == 2 {
            let p = Array(bytes.dropFirst(4))
            guard p.count == 39, p[0] < 10 else { throw BoseError.invalidPayload("Mode write") }
            var status = slots[Int(p[0])]
            status[1] = p[1]; status[2] = p[2]
            status.replaceSubrange(6..<38, with: p[3..<35])
            status[42] = p[38] == 1 ? 0 : p[35]
            status[43] = p[36]; status[44] = p[37]; status[46] = p[38]
            status[4] = p[1] == 0 && p[2] == 0 && Array(p[3..<7]) == Array("None".utf8) ? 0 : 1
            if corruptReadBack { status[42] = 9 }
            slots[Int(p[0])] = status
            sink.yield([31, 6, 3, 39] + p)
        } else {
            throw BoseError.invalidPayload("Unexpected command")
        }
    }
}

struct ModeTransactionTests {
    private func connect(_ transport: ModeTransport) async throws -> BoseDevice {
        let profile = try #require(DeviceRegistry.standard().profile(productID: 0x4066))
        return try await BoseDevice.connect(profile: profile, transport: transport)
    }

    @Test func presetsWithConfiguredZeroRemainSelectable() async throws {
        let device = try await connect(ModeTransport())
        for slot: UInt8 in [0, 1, 2] {
            try await device.selectMode(slot)
            #expect(try await device.currentMode() == slot)
        }
        await #expect(throws: BoseError.invalidState("Mode is not configured")) {
            try await device.selectMode(4)
        }
        await device.close()
    }

    @Test func repeatedSelectionReusesKnownModeList() async throws {
        let transport = ModeTransport()
        let device = try await connect(transport)
        try await device.selectMode(0)
        try await device.selectMode(3)
        try await device.selectMode(1)
        let enumerations = await transport.writes.filter { $0[0] == 31 && $0[1] == 1 }
        #expect(enumerations.count == 1)
        #expect(try await device.currentMode() == 1)
        await device.close()
    }

    @Test func repeatedAudioChangesReuseKnownModeList() async throws {
        let transport = ModeTransport()
        let device = try await connect(transport)
        let first = try await device.setCNC(5)
        let second = try await device.setCNC(4)
        #expect(first?.cnc == 5)
        #expect(second?.cnc == 4)
        let enumerations = await transport.writes.filter { $0[0] == 31 && $0[1] == 1 }
        #expect(enumerations.count == 3)
        await device.close()
    }

    @Test func savesThenReadsAndDeletesWithVerifiedLonestarrReset() async throws {
        let transport = ModeTransport()
        let device = try await connect(transport)
        let result = try await device.saveMode(ModeDraft(slot: 4, prompt: 11, name: "Work",
                                                        audio: AudioSettings(cnc: 6)))
        #expect(result.configured)
        #expect(result.audio?.cnc == 6)
        try await device.deleteMode(4)
        let writes = await transport.writes.filter { $0[1] == 6 }
        let deletion = try #require(writes.last)
        #expect(deletion[4 + 35] == 10)
        #expect(Array(deletion[(4 + 36)...]) == [0, 0, 0])
        await device.close()
    }

    @Test func deletingActiveModeSwitchesToFallbackPresetFirst() async throws {
        let transport = ModeTransport()
        let device = try await connect(transport)
        #expect(try await device.currentMode() == 3)
        try await device.deleteMode(3)
        #expect(try await device.currentMode() == 0)
        let commands = await transport.writes.map { [$0[1], $0[2]] }
        let selection = try #require(commands.firstIndex(of: [3, 5]))
        let deletion = try #require(commands.firstIndex(of: [6, 2]))
        #expect(selection < deletion)
        await device.close()
    }

    @Test func firmwareNormalizationAndWindRestoration() async throws {
        let transport = ModeTransport()
        let device = try await connect(transport)
        try await device.setWindBlock(true)
        try await device.setWindBlock(false)
        let writes = await transport.writes.filter { $0[1] == 6 }
        #expect(writes.count == 2)
        #expect(writes[0][4 + 38] == 1)
        #expect(writes[1][4 + 35] == 7)
        #expect(writes[1][4 + 38] == 0)
        await device.close()
    }

    @Test func presetAndAutoCNCRejectionHappenBeforeIO() async throws {
        let transport = ModeTransport()
        let device = try await connect(transport)
        await #expect(throws: BoseError.self) {
            try await device.saveMode(ModeDraft(slot: 0, prompt: 1, name: "Quiet", audio: AudioSettings(cnc: 0)))
        }
        await #expect(throws: BoseError.self) {
            try await device.saveMode(ModeDraft(slot: 4, prompt: 11, name: "Work",
                                                audio: AudioSettings(cnc: 0, automaticCNC: true)))
        }
        #expect(await transport.writes.isEmpty)
        await device.close()
    }

    @Test func acceptedWriteWithWrongFieldFailsVerification() async throws {
        let device = try await connect(ModeTransport(corruptReadBack: true))
        await #expect(throws: BoseError.verificationFailed("Mode fields differ after write")) {
            try await device.saveMode(ModeDraft(slot: 4, prompt: 11, name: "Work", audio: AudioSettings(cnc: 6)))
        }
        await device.close()
    }

    @Test func simultaneousModeWritesKeepReadBackInsideTransaction() async throws {
        let transport = ModeTransport()
        let device = try await connect(transport)
        async let a = device.saveMode(ModeDraft(slot: 4, prompt: 11, name: "Work", audio: AudioSettings(cnc: 3)))
        async let b = device.saveMode(ModeDraft(slot: 5, prompt: 12, name: "Music", audio: AudioSettings(cnc: 5)))
        _ = try await (a, b)
        #expect(await transport.writes.map { $0[1] } == [6, 1, 6, 1])
        await device.close()
    }
}
