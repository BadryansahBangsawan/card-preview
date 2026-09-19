import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginStatusText: String?

    var body: some View {
        Form {
            Toggle("Open at Login", isOn: loginBinding)
            if let loginStatusText {
                Label(loginStatusText, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .frame(width: FunTheme.panelWidth)
        .padding(12)
        .onAppear {
            loginEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { loginEnabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    loginEnabled = SMAppService.mainApp.status == .enabled
                    loginStatusText = nil
                } catch {
                    loginEnabled = SMAppService.mainApp.status == .enabled
                    loginStatusText = error.localizedDescription
                }
            }
        )
    }
}
