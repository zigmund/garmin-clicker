import AppKit
import ClickerCore
import Observation
import os

/// App state for the menu. Owns the `PairingController`, which is not
/// observable, and mirrors the parts of its state the UI shows.
@MainActor @Observable final class AppModel {
    private enum Key {
        static let keyScheme = "keyScheme"
        static let appLanguage = "appLanguage"
        static let pairingPromptAnswered = "pairingPromptAnswered"
    }

    private static let accessibilitySettings =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    // MARK: Observable state

    /// Set by the Bluetooth layer (Task 5); `.unknown` until then.
    var bluetooth: BluetoothState = .unknown

    /// Polled every 2 s.
    private(set) var canPostEvents: Bool

    var keyScheme: KeyScheme {
        didSet { defaults.set(keyScheme.rawValue, forKey: Key.keyScheme) }
    }

    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Key.appLanguage)
            l10n = L10n(language: language)
        }
    }

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue, launchAtLogin != LaunchAtLogin.isEnabled else { return }
            do {
                try LaunchAtLogin.set(launchAtLogin)
            } catch {
                Self.log.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
                launchAtLogin = oldValue
            }
        }
    }

    private(set) var l10n: L10n

    // Mirror of `controller` state, updated by `refresh()`.
    private(set) var pairedWatch: PairedWatch?
    private(set) var isPairingMode = false
    private(set) var connectedName: String?
    private var broadcastEnabled = true

    var isBroadcastEnabled: Bool {
        get { broadcastEnabled }
        set {
            controller.isBroadcastEnabled = newValue
            controllerChanged()
        }
    }

    var status: MenuBarStatus {
        .derive(bluetooth: bluetooth, canPostEvents: canPostEvents, isPaired: pairedWatch != nil,
                isPairingMode: isPairingMode, isBroadcastEnabled: broadcastEnabled,
                connectedName: connectedName)
    }

    var statusTitle: String {
        if case let .connected(name) = status { return l10n(status.titleKey, name) }
        return l10n(status.titleKey)
    }

    // MARK: Non-observable

    private static let log = Logger(subsystem: "com.zigmund.GarminClicker", category: "app")

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let environment = SystemEnvironment()
    @ObservationIgnored let controller: PairingController
    @ObservationIgnored private var approvalPrompt: ApprovalPrompt?
    @ObservationIgnored private var firstRunPrompt: AnyObject?
    @ObservationIgnored private var shownApproval: ApprovalRequest?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        controller = PairingController(store: UserDefaultsPairingStore(defaults: defaults),
                                       environment: SystemEnvironment())
        keyScheme = defaults.string(forKey: Key.keyScheme).flatMap(KeyScheme.init(rawValue:)) ?? .default
        let language = defaults.string(forKey: Key.appLanguage).flatMap(AppLanguage.init(rawValue:)) ?? .system
        self.language = language
        l10n = L10n(language: language)
        launchAtLogin = LaunchAtLogin.isEnabled
        canPostEvents = SystemEnvironment().canPostEvents
        refresh()
        startTicker()
    }

    // MARK: Actions

    func startPairing() {
        controller.startPairingMode()
        controllerChanged()
    }

    func stopPairing() {
        controller.stopPairingMode()
        controllerChanged()
    }

    func forgetWatch() {
        controllerChanged(sending: controller.forget())
    }

    func requestInputPermission() {
        _ = CGRequestPostEventAccess()
        NSWorkspace.shared.open(Self.accessibilitySettings)
    }

    func perform(_ action: SlideAction) {
        KeySender.send(keyScheme.keystroke(for: action))
    }

    /// First run: offer pairing once when no watch is paired.
    func onLaunch() {
        guard pairedWatch == nil, firstRunPrompt == nil,
              !defaults.bool(forKey: Key.pairingPromptAnswered) else { return }
        firstRunPrompt = Prompts.askStartPairing(l10n) { [weak self] start in
            guard let self else { return }
            firstRunPrompt = nil
            defaults.set(true, forKey: Key.pairingPromptAnswered)
            if start { startPairing() }
        }
    }

    // MARK: Hooks for the Bluetooth layer

    /// Re-reads controller state into the observable mirror and closes the
    /// approval window if its request is no longer pending (forget, broadcast
    /// off, watch unsubscribed — anything that cleared or replaced
    /// `controller.pendingApproval` without an answer). Call after every
    /// controller change made outside `AppModel`.
    func refresh() {
        if pairedWatch != controller.pairedWatch { pairedWatch = controller.pairedWatch }
        if isPairingMode != controller.isPairingModeActive { isPairingMode = controller.isPairingModeActive }
        if connectedName != controller.connectedWatchName { connectedName = controller.connectedWatchName }
        if broadcastEnabled != controller.isBroadcastEnabled { broadcastEnabled = controller.isBroadcastEnabled }

        if let shown = shownApproval, controller.pendingApproval != shown {
            approvalPrompt?.dismiss()
            approvalPrompt = nil
            shownApproval = nil
        }
    }

    /// Shows the approval window for a request the controller just created.
    func presentApproval(_ request: ApprovalRequest) {
        guard controller.pendingApproval == request else { return }
        approvalPrompt?.dismiss()
        shownApproval = request
        approvalPrompt = Prompts.askApproval(request, l10n) { [weak self] approved in
            self?.answerApproval(request, approved: approved)
        }
    }

    // MARK: Private

    private func answerApproval(_ request: ApprovalRequest, approved: Bool) {
        approvalPrompt = nil
        shownApproval = nil
        // Never resolve a different request than the one the user saw.
        guard controller.pendingApproval == request else { return }
        controllerChanged(sending: controller.resolveApproval(approved: approved))
    }

    /// Single funnel after AppModel changes the controller. Task 5 sends
    /// `updates` to the watches and refreshes advertising here.
    private func controllerChanged(sending updates: [StatusUpdate] = []) {
        refresh()
    }

    /// 1 s tick: keeps pairing-mode expiry visible; every 2nd tick polls the
    /// event posting permission and the login item status (it can change in
    /// System Settings).
    private func startTicker() {
        ticker = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                tick += 1
                if tick.isMultiple(of: 2) {
                    let allowed = environment.canPostEvents
                    if canPostEvents != allowed { canPostEvents = allowed }
                    let registered = LaunchAtLogin.isEnabled
                    if launchAtLogin != registered { launchAtLogin = registered }
                }
                if isPairingMode || controller.isPairingModeActive {
                    controllerChanged()
                }
            }
        }
    }
}
