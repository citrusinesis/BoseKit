extension BoseDevice {
    @discardableResult
    public func setCNC(_ level: CNCLevel) async throws -> AudioSettings? {
        try await transaction { device in
            switch device.profile.noiseControl {
            case .directCNC:
                _ = try await device.writeValue(BoseFeatures.cnc, level)
                return nil
            case .audioSettings, .modeConfiguration:
                return try await device.modifyAudio { audio, modeSlot in
                    if modeSlot != nil && audio.windBlock { throw BoseError.invalidState(.windBlockLocksCNC) }
                    audio.cnc = level
                }
            case .unavailable, .anr:
                throw BoseError.unsupported(.continuousNoiseControl)
            }
        }
    }

    @discardableResult
    public func setWindBlock(_ enabled: Bool) async throws -> AudioSettings {
        try await transaction { device in
            try device.check(.windBlock, .write)
            var remember: (slot: UInt8, cnc: CNCLevel)?
            var restoredSlot: UInt8?
            let actual = try await device.modifyAudio { audio, modeSlot in
                if let modeSlot {
                    if enabled && !audio.windBlock { remember = (modeSlot, audio.cnc) }
                    if !enabled {
                        restoredSlot = modeSlot
                        if let cnc = device.rememberedCNC[modeSlot] { audio.cnc = cnc }
                    }
                }
                audio.windBlock = enabled
            }
            if let remember { device.rememberedCNC[remember.slot] = remember.cnc }
            if let restoredSlot { device.rememberedCNC[restoredSlot] = nil }
            return actual
        }
    }

    @discardableResult
    public func setSpatialAudio(_ spatial: SpatialAudio) async throws -> AudioSettings {
        try await transaction { device in
            try device.check(.spatialAudio, .write)
            return try await device.modifyAudio { audio, _ in audio.spatial = spatial }
        }
    }

    @discardableResult
    public func setANCEnabled(_ enabled: Bool) async throws -> AudioSettings {
        try await transaction { device in
            try device.check(.ancToggle, .write)
            return try await device.modifyAudio { audio, _ in audio.ancEnabled = enabled }
        }
    }

    @discardableResult
    public func setAutomaticCNC(_ enabled: Bool) async throws -> AudioSettings {
        try await transaction { device in
            try device.check(.audioSettings, .write)
            return try await device.modifyAudio { audio, _ in audio.automaticCNC = enabled }
        }
    }

    private func modifyAudio(
        _ change: (inout AudioSettings, _ modeSlot: UInt8?) throws -> Void
    ) async throws -> AudioSettings {
        switch profile.noiseControl {
        case .audioSettings:
            var audio = try await readValue(BoseFeatures.audioSettings)
            try change(&audio, nil)
            return try await writeValue(BoseFeatures.audioSettings, audio)
        case .modeConfiguration:
            let mode = try await readActiveMode()
            guard var audio = mode.audio else { throw BoseError.invalidState(.currentModeHasNoAudioSettings) }
            guard let name = ModeName(rawValue: mode.name) else { throw BoseError.invalidState(.modeNameNotWritable) }
            try change(&audio, mode.id)
            let actual = try await writeMode(ModeDraft(slot: mode.id, prompt: mode.prompt, name: name, audio: audio))
            guard let actualAudio = actual.audio else { throw BoseError.verificationFailed(.modeFieldsDiffer) }
            return actualAudio
        case .unavailable, .anr, .directCNC:
            throw BoseError.unsupported(.audioSettings)
        }
    }
}
