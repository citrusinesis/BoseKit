# BoseKit

A macOS menu bar app and Swift library for controlling Bose headphones and earbuds
over Bluetooth, without the Bose app.

> BoseKit is an unofficial project and is not affiliated with or endorsed by Bose
> Corporation. Bose and QuietComfort are trademarks of Bose Corporation.

<p align="center">
  <img src="docs/images/sound-settings.png" width="420" alt="BoseKit settings window showing listening modes and ambient sound control">
</p>

## Features

- **Listening modes**: select, create, edit and delete modes; set favorites and the power-on mode
- **Noise control**: noise cancellation level, wind reduction, spatial audio and ANC, as the device supports
- **Equalizer**: bass, midrange and treble
- **Device settings**: name, multipoint, auto pause/answer, self voice, shortcut button, voice prompts and power off
- **Multipoint**: paired devices with their connection state, which one is playing and which one is this Mac
- **Menu bar**: quick controls and battery level; the icon can hide when no device is connected

Available controls depend on what each model supports. The interface is in English and Korean.

## Supported Devices

| Model | Status |
| --- | --- |
| QuietComfort Ultra Headphones (1st Gen) | [Verified on hardware](docs/qc-ultra-1st-gen.md) |
| QuietComfort Ultra Headphones (2nd Gen), QuietComfort Headphones (2nd Gen) | Implemented, untested |
| QuietComfort Ultra Earbuds (2nd Gen) | Implemented, untested |
| QuietComfort Headphones, QuietComfort 45 | Implemented, untested |
| QuietComfort 35 / 35 II | Implemented, untested |
| Noise Cancelling Headphones 700 | Implemented, untested |
| QuietComfort Earbuds, Ultra Open Earbuds | Implemented, untested |

Device protocol details are based on [bosectl](https://github.com/aaronsb/bosectl).
Reports for other models are welcome.

## Requirements

- App: macOS 26 or later
- Library (`BoseKitEngine`): macOS 14 or later
- Xcode with Swift 6
- The headphones must already be paired with the Mac

## Building

Open `BoseKit.xcodeproj` in Xcode, select the **BoseKit** scheme and run.
Allow Bluetooth access when prompted.

Run the library tests without Xcode:

```sh
swift test
```

## Using the Library

`BoseKitEngine` is also a Swift package:

```swift
import BoseKitEngine

let registry = try DeviceRegistry.standard()
guard let paired = RFCOMMTransport.pairedDevices().first(where: { $0.profile(in: registry) != nil }),
      let profile = paired.profile(in: registry) else { return }

let transport = await RFCOMMTransport(address: paired.id, channel: profile.rfcommChannel)
let device = try await BoseDevice.connect(profile: profile, transport: transport)

let battery = try await device.read(BoseFeatures.battery)
try await device.setCNC(5)
await device.close()
```

Writes are verified by reading the value back from the device. Check
`profile.supports(_:access:)` before offering a control.

## Project Structure

```text
BoseKitEngine/   Swift library: protocol, transport, device profiles and workflows
BoseKit/         SwiftUI menu bar app
docs/            Engine notes and per-device verification notes
```

See [docs/engine-notes.md](docs/engine-notes.md) for architecture and protocol
details, and for how to add a device.

## License

BoseKit is available under the [MIT License](LICENSE).

## Acknowledgements

Protocol layouts and device profiles reference
[bosectl](https://github.com/aaronsb/bosectl) (MIT). See `THIRD_PARTY_NOTICES.txt`.
