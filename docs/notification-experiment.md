# Notification Experiment

A plan for finding out what QuietComfort Ultra Headphones (1st Gen) report on their own, and which state changes they do not report.
The results decide how BoseKit replaces polling with events, and whether charging and on-head detection are worth adding as features.

## What Is Already Known

Verified on 2026-11-19; details are in [the device notes](qc-ultra-1st-gen.md).

- No function block is subscribed after connecting, and nothing arrives unsolicited without a subscription.
- The headphones accept a subscription to blocks 1, 2, 4, 5 and 31, and it lasts for the connection only.
- With the subscription, battery STATUS `2,2` arrives about every 55 seconds, changed or not.
- STATUS `5,4` arrives with a first byte of `00`, `01` or `02`; its meaning is unknown.

## Method

`bosekit-probe monitor --snapshots` keeps printing every packet while it reads labels from standard input.
Each label takes a snapshot of the readable registers and prints what changed since the previous snapshot.
One action therefore answers two questions at once: whether the headphones pushed a packet, and whether a value changed.

- A value that changes without a push must stay on polling.
- A value that is pushed can be refreshed from the event instead.

Each action follows the same rhythm: type a label and press Return, perform the action, wait ten seconds, type a second label and press Return.
The labels in the table are suggestions; any text works.

## Preparation

- Quit BoseKit, because only one control connection can be open at a time.
- Turn the headphones on and connect a second device, such as a phone, through multipoint.
- Keep a charging cable within reach.
- Note whether this Mac is the audio source when the run starts.

Run the probe from `Packages/BoseKitEngine` and keep a copy of the output:

```sh
swift run bosekit-probe monitor --snapshots 2>&1 | tee notification-run-1.log
swift run bosekit-probe monitor --snapshots --subscribe 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31 2>&1 | tee notification-run-2.log
```

The first command is step 0 and writes nothing to the headphones.
The second command covers every later step.
If the headphones reject the full bitmap, repeat with `--subscribe 1,2,4,5,31`.

## Steps

| Step | Action | Question |
| --- | --- | --- |
| 0 | Connect without a subscription and take one snapshot labelled `baseline` | Which registers answer, and which error code rejects the others; whether charger detect (`2,5`), on-head detection (`2,9`, `1,16`), AUX (`2,3`) and button (`2,12`) exist on this model |
| 1 | Connect with every block requested | Which blocks the headphones accept; the reported bitmap is the answer |
| 2 | Leave the headphones alone for three minutes | Whether battery is the only periodic report |
| 3 | On this Mac: play, pause, resume, next track, stop | What `00`, `01` and `02` in `5,4` mean, and what the two `ff` bytes are |
| 4 | Change the volume on the Mac, then on the headphones | Which register holds the volume and whether it is pushed |
| 5 | Switch modes three times with the headphones' button | Whether a mode change made on the headphones is pushed |
| 6 | Press and hold the shortcut button | Whether a button event arrives |
| 7 | Plug in the charging cable, wait thirty seconds, unplug it | Whether charging is pushed, and whether the battery report cadence changes |
| 8 | Take the headphones off for ten seconds and put them back on, once while playing and once while stopped | Whether on-head detection is pushed, and how auto pause relates to `5,4` |
| 9 | Start playback on the phone, then on this Mac | What the source switch changes in `5,1` and block 4 |
| 10 | Turn Bluetooth off and on again on the phone | How the device list (`4,4`, `4,5`) changes and whether that is pushed |
| 11 | With the Bose app on the phone, change the equalizer or the name | Whether a setting changed by another host is pushed in block 1 |
| 12 | With two other devices connected to the headphones and the probe not running, start the probe, wait thirty seconds, then stop it | Whether this Mac's control connection takes one of the headphones' connections away from another device |
| 13 | Switch the headphones off with their power button | What arrives just before the connection drops |

Steps 3, 5, 7 and 8 matter most.
Steps 10 and 11 can be skipped when time is short.
Step 12 needs a third device and its own run, because the probe must start while the other two are already connected; check on both devices whether either lost its connection or its audio.
The whole run takes twenty to twenty-five minutes.

## What the Results Decide

| Result | Decision |
| --- | --- |
| Accepted blocks in step 1 | The subscription each profile declares |
| Pushed addresses in steps 3 to 11 | Which refresh scope each address invalidates, and which values no longer need polling |
| Step 5 | Whether modes and audio settings stay on polling |
| Steps 2 and 7 | Whether battery is updated from pushes and the thirty-second battery poll is removed |
| Steps 0, 7 and 8 | Whether charging state and on-head detection become app features |
| Error codes in step 0 | Hardware evidence for the device error classification |
| Step 12 | Whether BoseKit keeps connecting to every powered device automatically, or only on demand |

## Safety

- The only write is the subscription to `9,2`, which the headphones forget when the connection closes.
- Snapshots use GET only.
- The firmware update, control, debug and authentication blocks are not read.
- A register that never answers closes the session by timeout; the probe reconnects and skips it for the rest of the run.
  Repeated reconnects are a result in their own right: stop and record which register caused them.

## Not Covered

- Packets caused by BoseKit's own writes, such as duplicate STATUS after a mode selection.
  These are easier to observe once the app consumes events and logs them.
- Long-lived connections, and sleep and wake.
