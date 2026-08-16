import AVFAudio
import Foundation

@MainActor
final class MonitorViewModel: ObservableObject {
    @Published var isMonitoring = false
     var isRecording = false
     var recordings: [URL] = []
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

        engine.onRecordingFinished = { [weak self] url in
            DispatchQueue.main.async { [weak self] in
                self?.isRecording = false
                self?.recordings.insert(url, at: 0)
            }
        }

        presets = presetStore.loadPresets()
        recordings = loadRecordings()
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

    func toggleRecording() {
        errorMessage = nil

        do {
            if isRecording {
                engine.stopRecording()
            } else {
                try engine.startRecording()
                isRecording = true
            }
        } catch {
            errorMessage = "Failed to record audio: \(error.localizedDescription)"
        }
    }

    func selectBluetoothInput() {
        guard isMonitoring else {
            errorMessage = "Start monitoring before choosing a Bluetooth microphone."
            return
        }

        do {
            guard try engine.selectBluetoothInput() else {
                errorMessage = "No paired Bluetooth microphone is available. Pair one in iPhone Settings."
                return
            }
            refreshRouteStatus()
        } catch {
            errorMessage = "Failed to select Bluetooth input: \(error.localizedDescription)"
        }
    }

    func deleteRecording(_ recording: URL) {
        try? FileManager.default.removeItem(at: recording)
        recordings.removeAll { recordingURL in recordingURL == recording }
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

    private func loadRecordings() -> [URL] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }

        let directory = documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
        let recordings = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []

        return recordings.sorted { firstURL, secondURL in
            let firstDate = (try? firstURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let secondDate = (try? secondURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return firstDate > secondDate
        }
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
