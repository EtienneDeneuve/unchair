import SwiftUI

struct SettingsView: View {
    @Bindable var shell: MenuBarShell
    @State private var workMinutes: Double = 50
    @State private var breakSeconds: Double = 90
    @State private var postponeUntil: Date = Date().addingTimeInterval(30 * 60)

    var body: some View {
        Form {
            Section("Schedule") {
                LabeledContent("Work interval") {
                    HStack {
                        Slider(value: $workMinutes, in: 5...120, step: 5)
                        Text("\(Int(workMinutes)) min")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                LabeledContent("Break duration") {
                    HStack {
                        Slider(value: $breakSeconds, in: 30...300, step: 15)
                        Text("\(Int(breakSeconds)) s")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Text("Changes apply to the next completed or skipped break cycle.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Camera") {
                Text(shell.cameraProbeStatusText)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Button {
                    shell.runCameraProbe()
                } label: {
                    Label(
                        shell.isCameraProbeRunning ? "Testing…" : "Test camera",
                        systemImage: "camera.fill"
                    )
                }
                .disabled(shell.isCameraProbeRunning)
                Text("Looks for the green camera indicator in the menu bar, then confirms frames stay in memory and the indicator turns off.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Postpone until exact time") {
                DatePicker(
                    "Until",
                    selection: $postponeUntil,
                    displayedComponents: [.hourAndMinute]
                )
                Button("Postpone to selected time") {
                    shell.postpone(until: postponeUntil)
                }
                .disabled(!shell.canPostpone)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 420)
        .navigationTitle("Unchair Settings")
        .onAppear {
            workMinutes = shell.settings.workInterval.seconds / 60
            breakSeconds = shell.settings.breakDuration.seconds
            postponeUntil = Date().addingTimeInterval(30 * 60)
        }
        .onChange(of: workMinutes) { _, newValue in
            shell.updateSettings(
                BreakSettings(
                    workInterval: .minutes(newValue),
                    breakDuration: .seconds(breakSeconds)
                )
            )
        }
        .onChange(of: breakSeconds) { _, newValue in
            shell.updateSettings(
                BreakSettings(
                    workInterval: .minutes(workMinutes),
                    breakDuration: .seconds(newValue)
                )
            )
        }
    }
}
