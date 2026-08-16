import AVFAudio
import Foundation

final class ReverbProcessor {
    let node = AVAudioUnitReverb()

    init() {
        node.loadFactoryPreset(.mediumHall)
        node.wetDryMix = 35
    }

    func setWetDryMix(_ value: Float) {
        node.wetDryMix = min(max(value, 0), 100)
    }

    func setPreset(_ preset: AVAudioUnitReverbPreset) {
        node.loadFactoryPreset(preset)
    }
}
