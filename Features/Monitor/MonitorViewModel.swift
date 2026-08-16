import AVFAudio
import Foundation

@MainActor
final class MonitorViewModel: ObservableObject {
    @Published var isMonitoring = false
    @Published var routeDescription = "Not active"
    @Published var showBluetoothLatencyWarning = false
    @Published var showUnsafeOutputWarning = false
    @Published var errorMessage: String?
    @Published var inputLevel: Float = 0
    @Published var outputLevel: Float = 0
    @Published var clipDetected = false
    @Published var tremoloBackend: TremoloBackend = .native {
        didSet {
            engine.setTremoloBackend(tremoloBackend)
        }
    }
    @Published var enforceSafeRoute = true {
        didSet {
            engine.setRequireSafeOutputRoute(enforceSafeRoute)
            refreshRouteStatus()
        }
    }

    @Published var inputGain: Float = 1 {
        didSet { engine.setInputGain(inputGain) }
    }

    @Published var monitorLevel: Float = 0.9 {
        didSet { engine.setMonitorLevel(monitorLevel) }
    }

    @Published var reverbMix: Float = 35 {
        didSet { engine.setReverbMix(reverbMix) }
    }

    @Published var tremoloDepth: Float = 0.3 {
        didSet { engine.setTremoloDepth(tremoloDepth) }
    }

    @Published var tremoloRate: Float = 3.6 {
        didSet { engine.setTremoloRate(tremoloRate) }
    }

    @Published var reverbPreset: AVAudioUnitReverbPreset = .mediumHall {
        didSet { engine.setReverbPreset(reverbPreset) }
    }

    @Published var presets: [EffectPreset] = []

    private let engine = LiveMonitorEngine()
    private let presetStore = PresetStore()
    private var clipResetTask: Task<Void, Never>?

    init() {
        engine.onMeterUpdate = { [weak self] input, output, clip in
            guard let self else { return }
            self.inputLevel = self.smoothedLevel(current: self.inputLevel, incoming: input)
            self.outputLevel = self.smoothedLevel(current: self.outputLevel, incoming: output)
            self.handleClipState(clip)
        }

        engine.onRouteChanged = { [weak self] in
            self?.refreshRouteStatus()
        }

        presets = presetStore.loadPresets()
        engine.setRequireSafeOutputRoute(enforceSafeRoute)
        tremoloBackend = engine.tremoloBackend
        if let firstPreset = presets.first {
            applyPreset(firstPreset)
        }
    }

    func toggleMonitoring() {
        errorMessage = nil

        if isMonitoring {
            engine.stop()
            isMonitoring = false
            refreshRouteStatus()
            return
        }

        do {
            try engine.start()
            applyCurrentValues()
            isMonitoring = true
            refreshRouteStatus()
        } catch {
            isMonitoring = false
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
        }
    }

    func applyPreset(_ preset: EffectPreset) {
        inputGain = preset.inputGain
        monitorLevel = preset.monitorLevel
        reverbMix = preset.reverbMix
        reverbPreset = preset.reverbPreset
        tremoloDepth = preset.tremoloDepth
        tremoloRate = preset.tremoloRate
        refreshRouteStatus()
    }

    func saveCurrentAsPreset(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let preset = EffectPreset(
            name: trimmed,
            reverbMix: reverbMix,
            reverbPreset: reverbPreset,
            tremoloDepth: tremoloDepth,
            tremoloRate: tremoloRate,
            inputGain: inputGain,
            monitorLevel: monitorLevel
        )

        presets.insert(preset, at: 0)
        presetStore.savePresets(presets)
    }

    func refreshRouteStatus() {
        routeDescription = engine.routeDescription
        showBluetoothLatencyWarning = engine.isUsingBluetoothInput
        showUnsafeOutputWarning = enforceSafeRoute && !engine.hasSafeMonitoringOutput
    }

    private func smoothedLevel(current: Float, incoming: Float) -> Float {
        let alpha: Float = 0.35
        return current + alpha * (incoming - current)
    }

    private func handleClipState(_ clipNow: Bool) {
        guard clipNow else { return }

        clipDetected = true
        clipResetTask?.cancel()
        clipResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            self?.clipDetected = false
        }
    }

    private func applyCurrentValues() {
        engine.setInputGain(inputGain)
        engine.setMonitorLevel(monitorLevel)
        engine.setReverbMix(reverbMix)
        engine.setReverbPreset(reverbPreset)
        engine.setTremoloDepth(tremoloDepth)
        engine.setTremoloRate(tremoloRate)
    }
}
