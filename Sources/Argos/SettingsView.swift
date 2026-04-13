import SwiftUI

struct SettingsView: View {
    @AppStorage("smoothing") private var smoothing: Double = 0.85
    @AppStorage("sensitivity") private var sensitivity: Double = 1.0
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section("Tracking") {
                VStack(alignment: .leading) {
                    Text("Smoothing: \(smoothing, specifier: "%.2f")")
                    Slider(value: $smoothing, in: 0.5...0.99)
                    Text("Higher = smoother but more latency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("Sensitivity: \(sensitivity, specifier: "%.1f")×")
                    Slider(value: $sensitivity, in: 0.5...3.0)
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }

            Section("Device") {
                HStack {
                    Text("Xreal Air 2 Pro")
                    Spacer()
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Connected")
                        .foregroundStyle(.secondary)
                }
            }

            Section("About") {
                HStack {
                    Text("Argos")
                    Spacer()
                    Text("v0.1.0")
                        .foregroundStyle(.secondary)
                }
                Link("GitHub", destination: URL(string: "https://github.com/")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
    }
}
