import AVFAudio
import SwiftUI

struct MonitorView: View {
    @ObservedObject var viewModel: MonitorViewModel

    @State private var newPresetName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    presetCard
                    reverbCard
                    tremoloCard
                    levelsCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reverb Tool")
        }
        .onAppear {
            viewModel.refreshRouteStatus()
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Monitor")
                .font(.headline)

            Button(action: viewModel.toggleMonitoring) {
                Text(viewModel.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.isMonitoring ? Color.red : Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(viewModel.routeDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var levelsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Levels")
                .font(.headline)

            sliderRow(title: "Input Gain", value: $viewModel.inputGain, range: 0...2, format: "%.2f")
            sliderRow(title: "Monitor Level", value: $viewModel.monitorLevel, range: 0...1.5, format: "%.2f")
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
