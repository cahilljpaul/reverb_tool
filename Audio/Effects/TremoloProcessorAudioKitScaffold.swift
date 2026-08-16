import AVFAudio
import Foundation

#if canImport(AudioKit) && canImport(SoundpipeAudioKit)
import AudioKit
import SoundpipeAudioKit
#endif

/// Optional scaffold for an AudioKit-backed tremolo processor.
///
/// This file is intentionally isolated from the active signal path so the app
/// continues to build before AudioKit packages are added to your Xcode target.
///
/// Integration outline:
/// 1) Add AudioKit + SoundpipeAudioKit via Swift Package Manager.
/// 2) Implement `buildNodeChain` with your preferred AudioKit node graph.
/// 3) Swap `TremoloProcessor` usage in LiveMonitorEngine to this type.
final class TremoloProcessorAudioKitScaffold {
    let fallbackNode = AVAudioMixerNode()

    var node: AVAudioNode {
        fallbackNode
    }

    private(set) var depth: Float = 0.4
    private(set) var rateHz: Float = 4.0
    private(set) var monitorGain: Float = 1.0

    func setRateHz(_ value: Float) {
        rateHz = min(max(value, 0.1), 12)
    }

    func setDepth(_ value: Float) {
        depth = min(max(value, 0), 1)
    }

    func setMonitorGain(_ value: Float) {
        monitorGain = min(max(value, 0), 1.8)
        fallbackNode.outputVolume = monitorGain
    }

    func start() {
        fallbackNode.outputVolume = monitorGain
    }

    func stop() {
        fallbackNode.outputVolume = monitorGain
    }

    #if canImport(AudioKit) && canImport(SoundpipeAudioKit)
    /// Replace this placeholder with a concrete AudioKit node chain.
    ///
    /// Example target design:
    /// input AVAudioNode -> AudioKit bridge node -> SoundpipeAudioKit Tremolo -> AVAudioNode output
    ///
    /// Keep API parity with TremoloProcessor to make swapping easy in LiveMonitorEngine.
    func buildNodeChain() {
        // TODO: Implement once package dependencies are linked to the target.
    }
    #endif
}

extension TremoloProcessorAudioKitScaffold: TremoloProcessing {}
