import SwiftUI

struct SettingsView: View {
    @Bindable var model: HardlockModel
    @State private var isConfirmingUninstall = false

    var body: some View {
        Form {
            Section {
                Toggle("Lock after login", isOn: Binding(
                    get: { model.isEnabled },
                    set: { model.setEnabled($0) }
                ))
                .disabled(model.isBusy)

                Stepper(value: $model.delay, in: Preferences.delayRange) {
                    LabeledContent("Delay after login") {
                        Text(model.delay == 1 ? "1 second" : "\(model.delay) seconds")
                            .monospacedDigit()
                    }
                }
            } footer: {
                if model.needsApproval {
                    HStack(alignment: .firstTextBaseline) {
                        Label("Hardlock is turned off in Login Items.", systemImage: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                        Spacer()
                        Button("Open Login Items…") { model.openLoginItemsSettings() }
                    }
                } else {
                    Text("After an automatic login at startup, waits \(model.delay) s and then locks the screen. Your apps keep running behind the lock screen.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Open Hardlock at login", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section {
                LabeledContent("Test the lock") {
                    Button("Lock Now") { model.lockNow() }
                }
            }

            Section {
                LabeledContent("Remove Hardlock from this Mac") {
                    Button("Uninstall…", role: .destructive) { isConfirmingUninstall = true }
                        .disabled(model.isBusy)
                }
            }
        }
        .confirmationDialog("Uninstall Hardlock?", isPresented: $isConfirmingUninstall) {
            Button("Uninstall", role: .destructive) { model.uninstall() }
        } message: {
            Text("Turns off the lock after login, removes Hardlock from Login Items, deletes its settings and moves the app to the Trash.")
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { model.refresh() }
    }
}
