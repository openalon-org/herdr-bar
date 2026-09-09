import AppKit
import Combine
import HerdrCore
import ServiceManagement

/// Wraps `SMAppService.mainApp`. Status is the login-item list, not JSON.
@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var packed = false
    @Published private(set) var status: LoginItem.Registration = .notRegistered
    @Published private(set) var lastError: String?

    var isOn: Bool { LoginItem.isOn(status) }
    var footer: String { LoginItem.footer(packed: packed, status: status, error: lastError) }

    private var cancellable: AnyCancellable?

    init() {
        refresh()
        cancellable = NotificationCenter.default
            .publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func refresh() {
        packed = LoginItem.isPackedApp(bundlePath: Bundle.main.bundlePath)
        status = Self.map(SMAppService.mainApp.status)
    }

    func setEnabled(_ on: Bool) {
        lastError = nil
        do {
            if on {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func map(_ status: SMAppService.Status) -> LoginItem.Registration {
        switch status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        case .notRegistered: return .notRegistered
        @unknown default: return .notRegistered
        }
    }
}
