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
            mode: .measurement,
            options: [.allowBluetooth, .allowBluetoothA2DP, .mixWithOthers]
        )

        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.0029)
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
}
