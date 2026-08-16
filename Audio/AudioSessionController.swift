import AVFAudio
import Foundation

final class AudioSessionController {
    private let session = AVAudioSession.sharedInstance()

    private let safeOutputTypes: Set<AVAudioSession.Port> = [
        .headphones,
        .bluetoothA2DP,
        .bluetoothHFP,
        .bluetoothLE,
        .usbAudio,
        .lineOut,
        .airPlay
    ]

    func configureForLiveMonitoring() throws {
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetooth]
        )

        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func deactivate() throws {
        try session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    var currentRouteDescription: String {
        let outputs = session.currentRoute.outputs.map(\.portName).joined(separator: ", ")
        let inputs = session.currentRoute.inputs.map(\.portName).joined(separator: ", ")
        return "Input: \(inputs.isEmpty ? "None" : inputs) | Output: \(outputs.isEmpty ? "None" : outputs)"
    }

    var isUsingBluetoothInput: Bool {
        session.currentRoute.inputs.contains { input in
            input.portType == .bluetoothHFP || input.portType == .bluetoothLE
        }
    }

    var hasSafeMonitoringOutput: Bool {
        session.currentRoute.outputs.contains { output in
            safeOutputTypes.contains(output.portType)
        }
    }

    func selectBluetoothInput() throws -> Bool {
        guard let input = session.availableInputs?.first(where: {
            $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE
        }) else {
            return false
        }

        try session.setPreferredInput(input)
        return true
    }
}
