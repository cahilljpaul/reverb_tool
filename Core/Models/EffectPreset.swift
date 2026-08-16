import AVFAudio
import Foundation

struct EffectPreset: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var reverbMix: Float
    var reverbPresetRaw: Int
    var tremoloDepth: Float
    var tremoloRate: Float
    var inputGain: Float
    var monitorLevel: Float

    init(
        id: UUID = UUID(),
        name: String,
        reverbMix: Float,
        reverbPreset: AVAudioUnitReverbPreset,
        tremoloDepth: Float,
        tremoloRate: Float,
        inputGain: Float,
        monitorLevel: Float
    ) {
        self.id = id
        self.name = name
        self.reverbMix = reverbMix
        self.reverbPresetRaw = Int(reverbPreset.rawValue)
        self.tremoloDepth = tremoloDepth
        self.tremoloRate = tremoloRate
        self.inputGain = inputGain
        self.monitorLevel = monitorLevel
    }

    var reverbPreset: AVAudioUnitReverbPreset {
        AVAudioUnitReverbPreset(rawValue: reverbPresetRaw) ?? .mediumHall
    }
}
