import AVFAudio
import Foundation

enum LiveMonitorEngineError: LocalizedError {
    case unsafeOutputRoute
    case recordingRequiresMonitoring

    var errorDescription: String? {
        switch self {
        case .unsafeOutputRoute:
            return "Connect headphones or another private output before starting monitoring."
        case .recordingRequiresMonitoring:
            return "Start monitoring before recording."
        }
    }
}

final class LiveMonitorEngine {
    private let engine = AVAudioEngine()
    private let sessionController = AudioSessionController()

    private let inputGainNode = AVAudioMixerNode()
    private var tremolo: TremoloProcessing
    private let reverb = ReverbProcessor()

    private var graphBuilt = false
    private var routeChangeObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private let meterQueue = DispatchQueue(label: "com.reverbtool.meter")
    private var latestInputLevel: Float = 0
    private var latestOutputLevel: Float = 0
    private var latestClipState = false
    private var requireSafeOutputRoute = true
    private var selectedBackend: TremoloBackend
    private var tremoloRateHz: Float = 3.6
    private var tremoloDepth: Float = 0.3
    private var tremoloMonitorGain: Float = 0.9
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?

    var onMeterUpdate: ((Float, Float, Bool) -> Void)?
    var onRouteChanged: (() -> Void)?
    var onRecordingFinished: ((URL) -> Void)?

    init(initialBackend: TremoloBackend = .native) {
        selectedBackend = initialBackend
        tremolo = LiveMonitorEngine.makeTremolo(for: initialBackend)

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAudioRouteChange()
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
    }

    deinit {
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        stop()
    }

    func start() throws {
        try sessionController.configureForLiveMonitoring()

        guard !requireSafeOutputRoute || sessionController.hasSafeMonitoringOutput else {
            throw LiveMonitorEngineError.unsafeOutputRoute
        }

        if !graphBuilt {
            buildGraph()
        }

        try engine.start()
        tremolo.start()
        onRouteChanged?()
    }

    func stop() {
        stopRecording()
        tremolo.stop()
        engine.stop()
        try? sessionController.deactivate()
    }

    var isRecording: Bool {
        recordingFile != nil
    }

    func startRecording() throws {
        guard engine.isRunning else {
            throw LiveMonitorEngineError.recordingRequiresMonitoring
        }

        guard recordingFile == nil else { return }

        let recordingsDirectory = try Self.recordingsDirectory()
        let url = recordingsDirectory.appendingPathComponent(
            "Reverb Tool \(Self.recordingDateFormatter.string(from: Date())).caf"
        )
        let format = reverb.node.outputFormat(forBus: 0)

        recordingFile = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        recordingURL = url
    }

    func stopRecording() {
        guard let recordingURL else { return }

        recordingFile = nil
        self.recordingURL = nil
        onRecordingFinished?(recordingURL)
    }

    func selectBluetoothInput() throws -> Bool {
        try sessionController.selectBluetoothInput()
    }

    func setInputGain(_ value: Float) {
        inputGainNode.outputVolume = min(max(value, 0), 2)
    }

    func setMonitorLevel(_ value: Float) {
        tremoloMonitorGain = value
        tremolo.setMonitorGain(value)
    }

    func setTremoloRate(_ value: Float) {
        tremoloRateHz = value
        tremolo.setRateHz(value)
    }

    func setTremoloDepth(_ value: Float) {
        tremoloDepth = value
        tremolo.setDepth(value)
    }

    func setReverbMix(_ value: Float) {
        reverb.setWetDryMix(value)
    }

    func setReverbPreset(_ preset: AVAudioUnitReverbPreset) {
        reverb.setPreset(preset)
    }

    func setRequireSafeOutputRoute(_ enabled: Bool) {
        requireSafeOutputRoute = enabled
    }

    func setTremoloBackend(_ backend: TremoloBackend) {
        guard backend != selectedBackend else { return }

        let wasRunning = engine.isRunning
        if wasRunning {
            tremolo.stop()
            engine.pause()
        }

        let oldNode = tremolo.node
        tremolo = LiveMonitorEngine.makeTremolo(for: backend)
        selectedBackend = backend
        applyTremoloState()

        if graphBuilt {
            reconnectTremoloNode(from: oldNode, to: tremolo.node)
        }

        if wasRunning {
            do {
                try engine.start()
                tremolo.start()
            } catch {
                stop()
            }
        }
    }

    var tremoloBackend: TremoloBackend {
        selectedBackend
    }

    var routeDescription: String {
        sessionController.currentRouteDescription
    }

    var isUsingBluetoothInput: Bool {
        sessionController.isUsingBluetoothInput
    }

    var hasSafeMonitoringOutput: Bool {
        sessionController.hasSafeMonitoringOutput
    }

    private func buildGraph() {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        engine.attach(inputGainNode)
        engine.attach(tremolo.node)
        engine.attach(reverb.node)

        inputGainNode.outputVolume = 1

        engine.connect(inputNode, to: inputGainNode, format: inputFormat)
        engine.connect(inputGainNode, to: tremolo.node, format: inputFormat)
        engine.connect(tremolo.node, to: reverb.node, format: inputFormat)
        engine.connect(reverb.node, to: engine.mainMixerNode, format: inputFormat)

        applyTremoloState()

        installMetering(inputFormat: inputFormat)

        graphBuilt = true
    }

    private func reconnectTremoloNode(from oldNode: AVAudioNode, to newNode: AVAudioNode) {
        let inputFormat = engine.inputNode.inputFormat(forBus: 0)

        engine.disconnectNodeInput(oldNode)
        engine.disconnectNodeOutput(oldNode)
        engine.detach(oldNode)

        engine.attach(newNode)
        engine.connect(inputGainNode, to: newNode, format: inputFormat)
        engine.connect(newNode, to: reverb.node, format: inputFormat)
    }

    private static func makeTremolo(for backend: TremoloBackend) -> TremoloProcessing {
        switch backend {
        case .native:
            return TremoloProcessor()
        case .audioKitScaffold:
            return TremoloProcessorAudioKitScaffold()
        }
    }

    private func applyTremoloState() {
        tremolo.setRateHz(tremoloRateHz)
        tremolo.setDepth(tremoloDepth)
        tremolo.setMonitorGain(tremoloMonitorGain)
    }

    private func installMetering(inputFormat: AVAudioFormat) {
        inputGainNode.removeTap(onBus: 0)
        reverb.node.removeTap(onBus: 0)

        inputGainNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let (inputLevel, inputClip) = Self.extractLevelAndClip(from: buffer)
            self.meterQueue.async {
                self.latestInputLevel = inputLevel
                self.latestClipState = self.latestClipState || inputClip

                let currentInput = self.latestInputLevel
                let currentOutput = self.latestOutputLevel
                let currentClip = self.latestClipState

                DispatchQueue.main.async {
                    self.onMeterUpdate?(currentInput, currentOutput, currentClip)
                }

                self.latestClipState = false
            }
        }

        reverb.node.installTap(onBus: 0, bufferSize: 512, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.recordingFile?.write(from: buffer)
            let (outputLevel, outputClip) = Self.extractLevelAndClip(from: buffer)
            self.meterQueue.async {
                self.latestOutputLevel = outputLevel
                self.latestClipState = self.latestClipState || outputClip

                let currentInput = self.latestInputLevel
                let currentOutput = self.latestOutputLevel
                let currentClip = self.latestClipState

                DispatchQueue.main.async {
                    self.onMeterUpdate?(currentInput, currentOutput, currentClip)
                }

                self.latestClipState = false
            }
        }
    }

    private static func extractLevelAndClip(from buffer: AVAudioPCMBuffer) -> (level: Float, clip: Bool) {
        guard
            let channelData = buffer.floatChannelData,
            buffer.frameLength > 0
        else {
            return (0, false)
        }

        let frameCount = Int(buffer.frameLength)
        let samples = channelData[0]

        var sum: Float = 0
        var peak: Float = 0

        for i in 0..<frameCount {
            let sample = samples[i]
            let absSample = abs(sample)
            sum += sample * sample
            if absSample > peak {
                peak = absSample
            }
        }

        let rms = sqrt(sum / Float(frameCount))
        let db = 20 * log10(max(rms, 0.000_01))
        let normalized = min(max((db + 60) / 60, 0), 1)
        let clip = peak >= 0.99

        return (normalized, clip)
    }

    private static func recordingsDirectory() throws -> URL {
        let directory = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Recordings", isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static let recordingDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    private func handleAudioRouteChange() {
        onRouteChanged?()

        if engine.isRunning {
            guard !requireSafeOutputRoute || sessionController.hasSafeMonitoringOutput else {
                stop()
                return
            }

            do {
                engine.stop()
                try sessionController.configureForLiveMonitoring()
                try engine.start()
            } catch {
                stop()
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return
        }

        switch type {
        case .began:
            stop()
        case .ended:
            do {
                try start()
            } catch {
                stop()
            }
        @unknown default:
            break
        }
    }
}
