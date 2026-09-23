import AppKit
import Combine
import ServiceManagement

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published private(set) var errorMessage: String?

    var enabled: Bool { status == .enabled || status == .requiresApproval }

    var statusText: String {
        if let errorMessage { return errorMessage }
        switch status {
        case .enabled: return "Enabled"
        case .requiresApproval: return "Needs approval in System Settings → General → Login Items"
        case .notRegistered: return "Off"
        case .notFound: return "This app bundle is not eligible for login registration"
        @unknown default: return "Status unavailable"
        }
    }

    func refresh() { status = SMAppService.mainApp.status }

    func setEnabled(_ value: Bool) {
        errorMessage = nil
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }
}
