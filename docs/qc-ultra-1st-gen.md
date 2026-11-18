# QuietComfort Ultra Headphones (1st Gen)

Profile `lonestarr`, product ID `0x4066`, RFCOMM channel 2.
Verified on user hardware on 2026-11-17 with firmware `1.6.7+g6ebabd2`.

## Modes

- Mode STATUS is 47 bytes; writes are 39 bytes. There are 10 slots.
- Presets are slots 0–2 and are not writable; custom slots are 3–9.
- Presets can report `configured=0`. Selection relies on the profile's `presetSlots`;
  the configured flag only gates custom slots.
- Custom modes cannot use automatic CNC; it is rejected before sending.
- Enabling wind block forces CNC to 0. BoseKit remembers the previous CNC per slot
  for the connection and restores it when wind block is turned off.
- Deleting a mode writes name `None`, prompt 0, CNC 10 and all other settings off,
  then checks that `configured` is cleared.
- Mode names are limited to 31 UTF-8 bytes.

## Settings

- Multipoint is bit 0 of the multipoint payload.
- The shortcut button's supported-action bitmap is big-endian.
- Voice prompt writes keep the upper flag bits. Toggling voice prompts also changes
  payload byte 6, and this change is not known to be reversible.
- Direct CNC writes, the default (power-on) mode and AudioSettings are not supported.

## Multipoint

| Request | Response payload | Meaning |
| --- | --- | --- |
| GET `4,4` | 1 byte + 6-byte address × N | Paired devices, most recently used first |
| GET `4,5` + address | address + status + 2 bytes + UTF-8 name | Device name and state |
| GET `4,9` | 6-byte address | Address of the requesting host |
| GET `5,1` | `00 0f 01` + address | Current audio source |

- In the `4,5` status byte, bit 0 means connected and bit 1 marks the requesting host.
- The first byte of `4,4` appears to be a per-position connection bitmask; BoseKit uses
  the `4,5` status instead.
- Source routing (`4,12`) is rejected with error code `04`.
- The headphones do not take playback away from a device that is playing. The source
  changes only after the current device stops and another starts playing.

## Connection

- Reopening RFCOMM immediately after closing is unreliable. The transport waits for
  the close callback plus 150 ms, which passed ten consecutive connect/read/close cycles.
- The IOBluetooth paired-device cache can report the headphones as disconnected while
  a control session is active.

## Not Yet Verified

- Power off, pairing mode, renaming, voice prompt writes and turning multipoint off
- Notifications from physical button presses
- Sleep/wake and long-lived connections
