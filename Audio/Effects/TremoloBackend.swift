import AVFAudio
import Foundation

enum TremoloBackend: String, CaseIterable, Identifiable {
    case native
    case audioKitScaffold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .native:
            return "Native"
        case .audioKitScaffold:
            return "AudioKit Scaffold"
        }
    }
}

protocol TremoloProcessing: AnyObject {
    var node: AVAudioNode { get }
    func setRateHz(_ value: Float)
    func setDepth(_ value: Float)
    func setMonitorGain(_ value: Float)
    func start()
    func stop()
}
