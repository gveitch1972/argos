import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: GlassesManager

    @AppStorage("smoothing") private var smoothing: Double = 0.85
    @AppStorage("sensitivity") private var sensitivity: Double = 1.0
    @AppStorage("deadZone") private var deadZone: Double = 0.005

    private func imuRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 36, alignment: .leading)
            Text(String(format: "%.4f rad", value)).monospacedDigit()
        }
    }

    var body: some View {
        Form {
            Section("Status") {
                HStack {
                    Circle()
                        .fill(manager.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(manager.isConnected ? "Xreal Air 2 Pro connected" : "No glasses found")

                }
                if manager.isConnected {
                    VStack(alignment: .leading, spacing: 2) {
                        imuRow("Pitch", manager.pitch)
                        imuRow("Yaw",   manager.yaw)
                        imuRow("Roll",  manager.roll)
                    }
                    .font(.caption)
                }
            }

            Section("Tracking") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Output smoothing: \(smoothing, specifier: "%.2f")")
                    Slider(value: $smoothing, in: 0.5...0.99)
                    Text("Higher = smoother but more lag")
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sensitivity: \(sensitivity, specifier: "%.1f")×")
                    Slider(value: $sensitivity, in: 0.25...3.0)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Dead zone: \(deadZone, specifier: "%.3f") rad")
                    Slider(value: $deadZone, in: 0.001...0.05)
                    Text("Minimum head movement before display shifts")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Actions") {
                HStack {
                    Button("Lock position") {
                        Task { await manager.lockScreenPosition() }
                    }
                    Button("Reset") {
                        Task { await manager.resetOrientation() }
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Argos v0.1.0")
                    Spacer()
                    Link("github.com/gveitch1972/argos",
                         destination: URL(string: "https://github.com/gveitch1972/argos")!)
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .padding()
    }
}
