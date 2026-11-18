# Engine Notes

Implementation details for contributors. For an overview, see the [README](../README.md).

## Layers

| Layer | Responsibility |
| --- | --- |
| `BMAPTransport` | One connection lifetime; asynchronous open/write/close and a byte stream |
| `RFCOMMTransport` | IOBluetooth adapter, paired devices and cached SDP identities |
| `BMAPPacket` / `BMAPDecoder` | Value types; preserve flags and accumulate partial frames |
| `BMAPSession` | Actor with explicit FIFO requests, bounded response collection, cancellation and events |
| `BoseFeature<Value, Input>` | Typed, Sendable payload codecs; read-only features use `Never` as input |
| `DeviceProfile` / `DeviceRegistry` | Product matching, startup commands, capability access and mode policies |
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
- Unsolicited packets are available through per-subscriber `AsyncStream` events
  (bounded to 256 packets). Response matching never depends on these streams.
- Errors distinguish malformed device payloads (`invalidPayload`), rejected caller
  values (`invalidArgument`) and device states that forbid an operation (`invalidState`).

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

- Discovery runs every five seconds; each supported paired device gets its own
  control connection, even when its audio is connected to another host.
- Visible controls poll live state every five seconds and all settings every 30
  seconds; hidden controls only probe battery every 30 seconds. User actions
  interrupt a poll between requests.
- A healthy control session takes precedence over the paired-device cache, whose
  connection flag can be stale.
- Unavailable devices retry with bounded backoff; explicit disconnection or power
  off stops automatic reconnection.

## Device Notes

Verified behavior for individual models is documented per device, for example
[QuietComfort Ultra Headphones (1st Gen)](qc-ultra-1st-gen.md).

## Adding a Device

1. Reuse or implement a `ModeCodec` for the payload layout.
2. Describe the device with a `DeviceProfile`: feature access, startup packets and
   mode policy. Register it in a registry copy; duplicate IDs fail.
3. Add a `BoseFeature<Value, Input>` for each new register. `FeatureID` is an open
   string-backed type, so no enum needs editing.
4. Use `BMAPCommand<Response>` with a custom `ResponseRule` for new response patterns.
5. Add captured packet fixtures and tests, and record whether behavior comes from
   upstream inference or hardware verification.
