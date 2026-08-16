import AVFAudio
import Foundation

final class TremoloProcessor: TremoloProcessing {
    private let mixerNode = AVAudioMixerNode()
    var node: AVAudioNode { mixerNode }

    private let timerQueue = DispatchQueue(label: "com.reverbtool.tremolo")
    private var timer: DispatchSourceTimer?
    private var phase: Float = 0

    private var rateHz: Float = 4
    private var depth: Float = 0.4
    private var monitorGain: Float = 1

    func setRateHz(_ value: Float) {
        rateHz = min(max(value, 0.1), 12)
    }

    func setDepth(_ value: Float) {
        depth = min(max(value, 0), 1)
    }

    func setMonitorGain(_ value: Float) {
        monitorGain = min(max(value, 0), 1.8)
    }

    func start() {
        stop()

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            let step = 0.01 * self.rateHz * 2 * Float.pi
            self.phase += step
            if self.phase > 2 * Float.pi {
                self.phase -= 2 * Float.pi
            }

            let lfo = 0.5 + 0.5 * sin(self.phase)
            let gain = self.monitorGain * ((1 - self.depth) + self.depth * lfo)
            self.mixerNode.outputVolume = gain
        }

        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        mixerNode.outputVolume = monitorGain
    }
}
