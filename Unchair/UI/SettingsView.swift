import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Breaks") {
                Text("Work interval and break duration arrive with the scheduler.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 240)
        .navigationTitle("Unchair Settings")
    }
}
