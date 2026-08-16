import AVFAudio
import SwiftUI

struct MonitorView: View {
    @ObservedObject var viewModel: MonitorViewModel

    @State private var newPresetName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusCard
                    recordingCard
                    noiseGateCard
                    presetCard
                    reverbCard
                    tremoloCard
                    levelsCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reverb Tool")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.teal)
        }
        .onAppear {
            viewModel.refreshRouteStatus()
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live Monitor", systemImage: "waveform")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text(viewModel.isMonitoring ? "LIVE" : "STANDBY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(viewModel.isMonitoring ? .green : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(viewModel.isMonitoring ? Color.green.opacity(0.14) : Color.secondary.opacity(0.12), in: Capsule())
            }

            Button(action: viewModel.toggleMonitoring) {
                Label(
                    viewModel.isMonitoring ? "Stop Monitoring" : "Start Monitoring",
                    systemImage: viewModel.isMonitoring ? "stop.fill" : "play.fill"
                )
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.isMonitoring ? Color.red : Color.teal, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 12) {
                Button(action: viewModel.toggleRecording) {
                    Label(
                        viewModel.isRecording ? "Stop Recording" : "Record",
                        systemImage: viewModel.isRecording ? "stop.circle.fill" : "record.circle"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isRecording ? .red : .blue)
                .disabled(!viewModel.isMonitoring)

                Button(action: viewModel.selectBluetoothInput) {
                    Image(systemName: "mic.and.signal.meter")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Use paired Bluetooth microphone")
                .disabled(!viewModel.isMonitoring)
            }

            Label(viewModel.routeDescription, systemImage: "antenna.radiowaves.left.and.right")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Toggle("Require headphones/private output", isOn: $viewModel.enforceSafeRoute)
                .toggleStyle(.switch)

            if viewModel.showBluetoothLatencyWarning {
                Text("Bluetooth mic detected. You may hear extra latency.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if viewModel.showUnsafeOutputWarning {
                Text("No private output route detected. Connect headphones before monitoring.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            meterRow(title: "Input", value: viewModel.inputLevel, tint: .blue)
            meterRow(title: "Output", value: viewModel.outputLevel, tint: .green)

            if viewModel.clipDetected {
                Text("Clipping detected (held): lower input gain or monitor level.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recordings")
                .font(.headline)

            if viewModel.recordings.isEmpty {
                Text("No recordings yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.recordings, id: \.self) { recording in
                    HStack {
                        Text(recording.deletingPathExtension().lastPathComponent)
                            .lineLimit(1)

                        Spacer()

                        ShareLink(item: recording) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share recording")

                        Button {
                            viewModel.deleteRecording(recording)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Delete recording")
                        .tint(.red)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var noiseGateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Noise Gate", systemImage: "waveform.slash")
                    .font(.headline)

                Spacer()

                Toggle("Noise Gate", isOn: $viewModel.noiseGateEnabled)
                    .labelsHidden()
            }

            sliderRow(
                title: "Threshold",
                value: $viewModel.noiseGateThreshold,
                range: -80 ... -10,
                format: "%.0f dB"
            )
            .disabled(!viewModel.noiseGateEnabled)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var presetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.presets) { preset in
                        Button(preset.name) {
                            viewModel.applyPreset(preset)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            HStack {
                TextField("Save current as...", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    viewModel.saveCurrentAsPreset(named: newPresetName)
                    newPresetName = ""
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var reverbCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reverb")
                .font(.headline)

            sliderRow(title: "Mix", value: $viewModel.reverbMix, range: 0...100, format: "%.0f%%")

            Picker("Preset", selection: $viewModel.reverbPreset) {
                ForEach(reverbOptions, id: \.self) { preset in
                    Text(reverbLabel(for: preset)).tag(preset)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var tremoloCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tremolo")
                .font(.headline)

            Picker("Backend", selection: $viewModel.tremoloBackend) {
                ForEach(TremoloBackend.allCases) { backend in
                    Text(backend.title).tag(backend)
                }
            }
            .pickerStyle(.segmented)

            sliderRow(title: "Depth", value: $viewModel.tremoloDepth, range: 0...1, format: "%.2f")
            sliderRow(title: "Rate", value: $viewModel.tremoloRate, range: 0.1...12, format: "%.1f Hz")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var levelsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Levels")
                .font(.headline)

            sliderRow(title: "Input Gain", value: $viewModel.inputGain, range: 0...2, format: "%.2f")
            sliderRow(title: "Monitor Level", value: $viewModel.monitorLevel, range: 0...1.5, format: "%.2f")
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func sliderRow(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundStyle(.secondary)
            }

            Slider(value: value, in: range)
        }
    }

    private func meterRow(title: String, value: Float, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value * 100))%")
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(value))
                .tint(tint)
        }
    }

    private let reverbOptions: [AVAudioUnitReverbPreset] = [
        .smallRoom,
        .mediumRoom,
        .largeRoom,
        .mediumHall,
        .largeHall,
        .plate
    ]

    private func reverbLabel(for preset: AVAudioUnitReverbPreset) -> String {
        switch preset {
        case .smallRoom: return "Small Room"
        case .mediumRoom: return "Medium Room"
        case .largeRoom: return "Large Room"
        case .mediumHall: return "Medium Hall"
        case .largeHall: return "Large Hall"
        case .plate: return "Plate"
        default: return "Other"
        }
    }
}
