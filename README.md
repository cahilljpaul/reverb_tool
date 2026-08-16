# Reverb Tool Starter (iOS)

This folder contains starter Swift files for a live vocal practice app:
- headset/built-in mic input
- live monitoring output
- reverb control
- tremolo control
- quick preset save/load
- live input/output metering and clip warning
- private output route safety gate
- route-lock toggle in UI (can disable for debug)
- clip warning hold behavior for readability

## 1) Create the iOS app shell in Xcode

1. Open Xcode.
2. Create a new project: iOS > App.
3. Product Name: `ReverbTool`.
4. Interface: SwiftUI.
5. Language: Swift.
6. Save the project in this workspace.

## 2) Add microphone permission

Open your app target `Info` tab and add:
- Privacy - Microphone Usage Description (`NSMicrophoneUsageDescription`)

Suggested value:
- `Reverb Tool needs microphone access for live vocal monitoring and effects.`

## 3) Add these starter files

Drag these folders into your Xcode project and check your app target:
- `App/`
- `Audio/`
- `Core/`
- `Features/`

## 4) Replace generated app entry point

If Xcode created another `@main` app file, either:
- replace its contents with `App/ReverbToolApp.swift`, or
- delete the generated one and keep this starter one.

## 5) Run on a real iPhone

Use a real device (not simulator) for mic/audio route testing.

Suggested first test:
1. Connect wired headphones.
2. Launch app and tap `Start Monitoring`.
3. Raise `Monitor Level` slowly.
4. Adjust `Reverb Mix`, `Tremolo Depth`, and `Tremolo Rate`.

## Notes and limits

- Bluetooth mic routes often have noticeable latency on iOS.
- Wired monitoring is best for songwriting practice.
- Current tremolo is implemented with gain modulation for MVP simplicity.
- This starter enforces a private output route for monitoring (headphones, Bluetooth audio, USB audio, line out, AirPlay) to reduce feedback risk.

## AudioKit tremolo upgrade path

This workspace does not include an Xcode project file yet, so package integration cannot be auto-wired here. Once you have your app target in Xcode:

1. Add Swift Package dependencies:
	- `https://github.com/AudioKit/AudioKit`
	- `https://github.com/AudioKit/SoundpipeAudioKit`
2. In your app target, select these products:
	- `AudioKit` from AudioKit package
	- `SoundpipeAudioKit` from SoundpipeAudioKit package
3. Keep deployment target at iOS 16+ (recommended for this starter).
4. Implement the AudioKit node graph inside `Audio/Effects/TremoloProcessorAudioKitScaffold.swift`.
5. In app UI, switch Tremolo Backend to `AudioKit Scaffold` and compare sound/latency against `Native`.
6. Once validated, you can rename the scaffold to the production tremolo class.

Included scaffold file:
- `Audio/Effects/TremoloProcessorAudioKitScaffold.swift`
- `Audio/Effects/TremoloBackend.swift` (shared backend enum/protocol)

## Next upgrade steps

1. Add input/output level metering.
2. Add a stricter output safety limiter profile.
3. Add route lock logic (headphones required) to prevent speaker feedback.
4. Implement background-safe interruption/resume behavior with user-facing status.

Status of these upgrades in this starter:
1. Metering: implemented.
2. Headphone/private-route safety gate: implemented.
3. Background interruption/route handling: implemented baseline.
4. AudioKit tremolo adapter: pending manual package integration in Xcode target.
5. Route-lock UI toggle: implemented.
6. Clip indicator hold/smoothing: implemented.
7. Runtime tremolo backend selector (Native vs AudioKit Scaffold): implemented.
