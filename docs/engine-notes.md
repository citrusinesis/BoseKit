# Engine Notes

Implementation details for contributors. For an overview, see the [README](../README.md).

## Layers

| Layer | Responsibility |
| --- | --- |
| `BMAPTransport` | One connection lifetime; asynchronous open/write/close and a byte stream |
| `RFCOMMTransport` | IOBluetooth adapter, paired devices and cached SDP identities |
| `BMAPPacket` / `BMAPDecoder` | Value types; preserve flags and accumulate partial frames |
| `BMAPSession` | Actor with explicit FIFO requests, bounded response collection, cancellation and events |
| `PayloadReader` / `PayloadWriter` | Sequential named-field payload layouts; every decoder states whether trailing bytes are allowed |
| `BoseFeature<Value, Input>` | Typed, Sendable payload codecs with a read-back confirmation; read-only features use `Never` as input |
| `DeviceProfile` / `DeviceRegistry` | Named per-device profiles (startup commands, capability access, mode policies) and product matching through `DeviceRegistry.standard` or a caller-built registry |
| `ModeCodec` | Injectable STATUS decoder and separate write encoder |
| `BoseDevice` | Serialized multi-command workflows and verified writes |
| `DeviceController` (app) | UI state, polling, reconnection and user intents for one device |

## Requests and Transactions

- Actor isolation does not serialize an operation across `await`, so both wire
  requests and read/modify/write/read-back workflows use explicit FIFO queues.
- Every read/modify/write runs as one engine transaction that reads the current
  device state itself, so a stale value on screen never overwrites newer device state.
- START requests wait for RESULT; PROCESSING is never completion.
- Mode enumeration collects STATUS packets until the enumeration RESULT has arrived
  and every expected slot is present. Profiles without a known slot count fall back
  to a 500 ms quiet interval. Both are bounded by an 8 second deadline.
- The device keeps the last enumerated mode list for the connection. Selecting a
  mode or changing the active mode's audio does not re-enumerate first; every mode
  write still verifies with a fresh enumeration.
- Timeout or cancellation of an in-flight request closes the session. BMAP has no
  transaction ID, so a late reply could otherwise be matched to a later request.
  Reconnect with a new transport; writes are never replayed automatically.
- Every received packet is published through per-subscriber `AsyncStream` events (bounded to 256 events), tagged as a `reply` to the request in flight or as `unsolicited`.
  A packet counts as a reply when its address is one the request in flight is waiting on, so a notification for that same address is indistinguishable from the reply.
  Response matching never depends on these streams.
- Errors distinguish malformed device payloads (`invalidPayload`), rejected caller values (`invalidArgument`), device states that forbid an operation (`invalidState`), operations a profile cannot perform (`unsupported`) and writes whose read-back does not match (`verificationFailed`).
  The last three carry typed reasons (`BoseError.InvalidState`, `BoseError.Unsupported`, `BoseError.VerificationFailure`).
  A device error packet reports `BoseError.device(_, code:detail:)` with its first payload byte as a `BMAPErrorCode`, or `code: nil` when the packet has no payload.
  Unknown codes keep their raw value.
  For `FblockSpecific` (`0xFF`) the byte after the code is kept uninterpreted as `detail`; every other code has `detail: nil`.
- The names of the error codes come from two third-party reverse-engineering projects derived from the vendor app, not from an official specification.
  Only `03` (`FblockNotSupp`), `04` (`FuncNotSupp`) and `05` (`OpNotSupp`) have been observed on hardware so far.
  `BMAPErrorCode.disposition` classifies them: `03`, `04` and `05` are `permanent`; `07` (`DataUnavailable`), `08` (`Runtime`), `09` (`Timeout`), `0A` (`InvalidState`) and `0C` (`Busy`) are `transient`; every other code, an unknown code and a missing code are `indeterminate`.

## Payloads

- Caller values with protocol limits are validated by their types (`CNCLevel`, `DeviceName`, `ModeName`, `FavoriteModes`, `VoicePromptLanguage`, `EQAdjustment` from `EQBand.adjustment(to:)`), so encoders cannot fail on them. Values reported by the device (`CNCStatus`, decoded names) stay raw.
- Payloads are exact-length only where a lonestarr capture shows the length: mode STATUS (all layouts) and the Bluetooth audio source (`00 0f 01` + address). Every other payload tolerates trailing bytes, because the other devices are unverified.
- The shortcut button payload is a 3-byte assignment followed by either nothing or a full 4-byte supported-action bitmap; a partial bitmap is rejected.
- Text fields (firmware, serial, model, device and source-device names) drop trailing NUL padding and reject an embedded NUL or invalid encoding. Mode names end at the first NUL of their 32-byte field.
- Changing the active mode's audio writes the mode back with its current name; a device-reported name that is not a valid `ModeName` fails with `invalidState(.modeNameNotWritable)` instead of being truncated.

## Transport

- Channel objects and delegates are confined to the main run loop. Cached
  discovery runs off the main actor and returns value snapshots.
- Writes use asynchronous RFCOMM APIs, respect the negotiated MTU and retain
  buffers until completion or channel teardown.
- Only the RFCOMM channel is closed; shared baseband/audio connections stay intact.
- Closing waits for the native close callback plus a configurable 150 ms settlement
  interval (2 second fallback). Immediate reopening was timing-sensitive on lonestarr.
- Profiles are selected only from SDP identity: Bluetooth vendor `0x009e` or USB
  vendor `0x05a7` with the matching vendor-ID source. Device names never select a profile.
- Host apps must provide a Bluetooth usage description and, when sandboxed, the
  Bluetooth entitlement.

## App Behavior

- Discovery runs every five seconds; each supported paired device gets its own control connection, even when its audio is connected to another host.
- Entries that share an address, such as the classic and LE identities of one headset, map to a single device.
- A device that is no longer paired has its control connection closed and is removed from the list.
- `RFCOMMTransport.pairedDevices()` throws `PairedDeviceListingError.systemListUnavailable` when macOS returns no list, which is distinct from an empty list.
  The app then keeps its current devices, logs the failure and continues maintaining the connections.
- Visible controls poll live state every five seconds and all settings every 30 seconds; hidden controls only probe battery every 30 seconds.
  User actions interrupt a poll between requests.
- User actions run one at a time in the order they were made, and the controls stay usable while they run.
  Only destructive actions (power off, deleting a mode) wait until no action is pending, and the mode editor is locked while its own save is in flight.
- The app shows only values the device has confirmed; it never shows a requested value before the device's read-back.
  Mode selection is the exception: the selected mode is highlighted at once and rolls back to the last confirmed mode if the device rejects it.
- When an action's workflow returns the device's read-back, that value is shown as soon as the action succeeds, including fields the device normalized, such as CNC forced to maximum by wind block.
- After the last pending action, one refresh covers whatever the actions could have changed beyond their own confirmed values.
  Self-contained settings (toggles, sidetone, ANR, name, default mode, shortcut, favorites, EQ, voice prompts, and saving a mode that is not active) need no refresh.
  Mode selection, audio changes and saving the active mode refresh live state, because the separately read CNC status follows the active mode.
  Deleting a mode, routing audio and changing multipoint refresh all settings, because they can change the mode list, the current mode, favorites, the audio source or the source devices, none of which the workflow returns.
  A failed action refreshes all settings so the screen returns to the device's state.
- A poll that is in flight when an action starts either finishes before the action runs or is discarded and repeated afterwards, so a value read before the action never replaces the value the action confirmed.
- The app's own control sessions decide which devices count as connected; the paired-device cache's connection flag can be stale and is ignored.
- The selection changes automatically only on control connection transitions.
  When a device connects while the selected device is not connected, the newly connected device is selected.
  When the selected device's connection is lost or the device is removed, the first connected device in the list is selected; without one, a lost device stays selected and a removed one falls back to the first device.
  Otherwise the selection stays where the user put it, including on a disconnected device.
- The selected device is remembered across launches; when it is no longer paired, the first device is selected.
- Unavailable devices retry with bounded backoff; explicit disconnection or power off stops automatic reconnection.
  An explicit disconnection is remembered per device across launches until the user connects again or the device is unpaired.
  Power off pauses reconnection only until the app relaunches.
- A device error while reading a feature follows the code's disposition.
  A `permanent` error hides the feature for the rest of the connection without probing it again.
  A `transient` error keeps the value shown before and retries on the next refresh that covers the feature.
  An `indeterminate` error hides the feature and probes it again on every full refresh.
  Reconnecting clears all of this.
- A failed user action shows a message for the device error code: not supported (`03`–`05`), invalid value (`06`), not possible in the current state (`0A`) or busy and temporarily unavailable (`07`–`09`, `0C`); other codes show the generic rejection message.

## Probing Notifications

`bosekit-probe` is a command-line tool in its own package, `Packages/BoseKitProbe`, for finding out what a device sends on its own and what changes when the user does something.
Quit BoseKit first, because only one control connection can be open at a time.

```sh
cd Packages/BoseKitProbe
swift run bosekit-probe list
swift run bosekit-probe monitor --address <AA:BB:CC:DD:EE:FF>
swift run bosekit-probe monitor --address <AA:BB:CC:DD:EE:FF> --subscribe 1,2,4,5,31
swift run bosekit-probe monitor --address <AA:BB:CC:DD:EE:FF> --snapshots
```

- `monitor` reads the notification subscription with GET `9,2` and then prints every packet with its origin until interrupted.
  Without `--subscribe` it writes nothing to the device.
  When the connection closes without Control-C, the tool reports it and exits with a failure status.
- Each event line shows the register name after the address when the probe knows one, for example `[2.2]   battery`.
  The names come from the engine's known addresses and from other open-source BMAP projects; they are reading aids, not verified meanings.
- `--subscribe` sends SETGET `9,2` with `01` followed by a 4-byte big-endian bitmap of function blocks, the request the Bose app sends to the Noise Cancelling Headphones 700 (`01 00 05 02 37`).
  `--subscribe none` sends an all-zero bitmap.
- A subscription lasts only for the connection on the QuietComfort Ultra Headphones (1st Gen); which blocks other models accept is not yet verified.

### Snapshots

`--snapshots` finds changes the device does not push.
Every line read from standard input is a free-text label; for each line the probe GETs every register in the snapshot set and prints a block headed by the time and the label.
The first block lists every register that answered and every register that returned a device error, with the error payload, so it doubles as a capability scan.
Later blocks list only the registers whose reply changed since the previous snapshot (old → new), or `no changes`.

- Pushes keep printing while monitoring, including during a snapshot. Replies are not printed as event lines in this mode, because the snapshot blocks report them.
- The default set holds GET-able registers of blocks 0, 1, 2, 4, 5, 9 and 31: the engine's known readable addresses and the registers other projects saw answering GET.
  It leaves out blocks 3 (firmware update), 7 (control), 8 (debug) and 18 (authentication), `0,12`, which looks like a secret in upstream captures, and registers that need an argument (`4,5`, `31,6`) or are START enumerations (`31,1`).
  `--snapshot-registers 2.5,2.9` replaces the set and `--skip-registers 2.2` removes registers from it.
- Snapshot GETs time out after 2 seconds. Because a timeout closes the session (see [Requests and Transactions](#requests-and-transactions)), the probe then reconnects with a new transport, runs the profile's startup packets, re-applies `--subscribe`, marks the register as unresponsive for the rest of the run and continues the snapshot.
  A device error reply is an ordinary result; a disconnect ends the run.
- End of input stops labeling but not monitoring; Control-C still closes the connection cleanly.
  To feed labels from another process, run the probe in the foreground on a FIFO and keep one writer open in a second shell, because the input ends when the last writer closes:

```sh
mkfifo /tmp/labels
swift run bosekit-probe monitor --snapshots < /tmp/labels

# in a second shell
exec 3> /tmp/labels
echo "before play" >&3
```

## Device Notes

Verified behavior for individual models is documented per device, for example
[QuietComfort Ultra Headphones (1st Gen)](qc-ultra-1st-gen.md).

## Adding a Device

1. Reuse or implement a `ModeCodec` for the payload layout.
2. Describe the device with a `DeviceProfile`: feature access, startup packets and mode policy.
   A built-in device becomes a named constant in `Profiles/DeviceProfile+Standard.swift` and joins the list behind `DeviceRegistry.standard`; the registry tests check that the standard set has no duplicate product or profile IDs, and `RFCOMMChannel` only admits channels 1...30.
   A caller-supplied profile goes through `DeviceRegistry(profiles:)` or `register(_:)` on a copy of `DeviceRegistry.standard`, which throw `duplicateProduct` or `duplicateProfile`.
3. Add a `BoseFeature<Value, Input>` for each new register, with a `confirm` predicate that checks the read-back value against the written input.
   `FeatureID` is an open string-backed type, so no enum needs editing.
4. Use `BMAPCommand<Response>` with a custom `ResponseRule` for new response patterns.
5. Add captured packet fixtures and tests.
   Record whether behavior comes from upstream inference or hardware verification in the README "Supported Devices" table and, for verified devices, in a device note under `docs/`.
