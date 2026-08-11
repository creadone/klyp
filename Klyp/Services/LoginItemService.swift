import Foundation
import ServiceManagement

enum LoginItemStatus: Equatable, Sendable {
  case disabled
  case enabled
  case requiresApproval
  case unavailable
}

@MainActor
protocol LoginItemServicing: AnyObject {
  func currentStatus() -> LoginItemStatus
  func setEnabled(_ enabled: Bool) throws -> LoginItemStatus
  func openSystemSettings()
}

@MainActor
final class SystemLoginItemService: LoginItemServicing {
  private let service: SMAppService

  init(service: SMAppService = .mainApp) {
    self.service = service
  }

  func currentStatus() -> LoginItemStatus {
    map(service.status)
  }

  func setEnabled(_ enabled: Bool) throws -> LoginItemStatus {
    do {
      if enabled {
        if service.status != .enabled && service.status != .requiresApproval {
          try service.register()
        }
      } else if service.status == .enabled || service.status == .requiresApproval {
        try service.unregister()
      }
    } catch {
      throw LoginItemServiceError.operationFailed
    }

    return currentStatus()
  }

  func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }

  private func map(_ status: SMAppService.Status) -> LoginItemStatus {
    switch status {
    case .notRegistered:
      .disabled
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .unavailable
    @unknown default:
      .unavailable
    }
  }
}
