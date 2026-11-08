import Carbon
import ClickerCore
import CoreGraphics

/// Live input permissions: event posting access and Secure Input state.
struct SystemEnvironment: InputEnvironment {
    var canPostEvents: Bool { CGPreflightPostEventAccess() }
    var secureInputActive: Bool { IsSecureEventInputEnabled() }
}
