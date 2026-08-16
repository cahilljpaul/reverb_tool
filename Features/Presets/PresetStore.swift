import AVFAudio
import Foundation

final class PresetStore {
    private let defaultsKey = "reverbtool.presets"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func loadPresets() -> [EffectPreset] {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? decoder.decode([EffectPreset].self, from: data),
            !decoded.isEmpty
        else {
            return Self.defaultPresets
        }

        return decoded
    }

    func savePresets(_ presets: [EffectPreset]) {
        guard let data = try? encoder.encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static let defaultPresets: [EffectPreset] = [
        EffectPreset(
            name: "Verse Air",
            reverbMix: 22,
            reverbPreset: .mediumChamber,
            tremoloDepth: 0.1,
            tremoloRate: 2.2,
            inputGain: 1,
            monitorLevel: 0.9
        ),
        EffectPreset(
            name: "Chorus Wide",
            reverbMix: 46,
            reverbPreset: .largeHall,
            tremoloDepth: 0.25,
            tremoloRate: 3.4,
            inputGain: 1,
            monitorLevel: 0.9
        ),
        EffectPreset(
            name: "Slow Pulse",
            reverbMix: 34,
            reverbPreset: .plate,
            tremoloDepth: 0.55,
            tremoloRate: 1.4,
            inputGain: 1,
            monitorLevel: 0.85
        ),
        EffectPreset(
            name: "Fast Pulse",
            reverbMix: 24,
            reverbPreset: .mediumRoom,
            tremoloDepth: 0.65,
            tremoloRate: 6.8,
            inputGain: 1,
            monitorLevel: 0.8
        ),
        EffectPreset(
            name: "Dry",
            reverbMix: 0,
            reverbPreset: .smallRoom,
            tremoloDepth: 0,
            tremoloRate: 2,
            inputGain: 1,
            monitorLevel: 1
        )
    ]
}
