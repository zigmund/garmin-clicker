import ClickerCore
import CoreBluetooth
import os

/// GATT server for the watch: publishes the service while Bluetooth is on and
/// broadcasting is enabled, advertises per `controller.advertisingMode`, and
/// feeds Command writes and Status subscriptions into the `PairingController`.
@MainActor final class BLEPeripheral: NSObject, CBPeripheralManagerDelegate {
    private static let log = Logger(subsystem: "com.zigmund.GarminClicker", category: "ble")

    private static let serviceUUID = CBUUID(string: WireUUID.service)
    private static let commandUUID = CBUUID(string: WireUUID.command)
    private static let statusUUID = CBUUID(string: WireUUID.status)
    private static let macInfoUUID = CBUUID(string: WireUUID.macInfo)

    /// Backoff for retrying a failed service add or advertising start.
    private static let initialRetryDelay: Duration = .seconds(2)
    private static let maxRetryDelay: Duration = .seconds(30)

    /// What is being advertised; compared to skip redundant restarts.
    private struct Advertisement: Equatable {
        var uuid: String
        var localName: String?

        var data: [String: Any] {
            var data: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: uuid)]]
            if let localName { data[CBAdvertisementDataLocalNameKey] = localName }
            return data
        }
    }

    private(set) var bluetooth: BluetoothState = .unknown

    private let controller: PairingController
    private let macName: String
    private let onAction: (SlideAction) -> Void
    private let onApprovalRequest: (ApprovalRequest) -> Void
    private let onApprovalCancelled: () -> Void
    private let onChange: () -> Void

    private var manager: CBPeripheralManager!
    /// Published (or being added) service; nil when not published.
    private var service: CBMutableService?
    private var statusCharacteristic: CBMutableCharacteristic?
    private var isServiceAdded = false
    private var advertisement: Advertisement?
    /// Centrals subscribed to Status, by identifier.
    private var subscribers: [UUID: CBCentral] = [:]
    /// Notifications not yet accepted by the transmit queue.
    private var queuedUpdates: [StatusUpdate] = []
    /// Pending retry after a failure; outside pairing mode nothing else would
    /// call `refreshAdvertising()` and the watch could never reconnect.
    private var retryTask: Task<Void, Never>?
    private var retryDelay = BLEPeripheral.initialRetryDelay

    init(controller: PairingController, macName: String,
         onAction: @escaping (SlideAction) -> Void,
         onApprovalRequest: @escaping (ApprovalRequest) -> Void,
         onApprovalCancelled: @escaping () -> Void,
         onChange: @escaping () -> Void) {
        self.controller = controller
        self.macName = macName
        self.onAction = onAction
        self.onApprovalRequest = onApprovalRequest
        self.onApprovalCancelled = onApprovalCancelled
        self.onChange = onChange
        super.init()
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }

    // MARK: API

    /// Notifies Status to the given centrals (those still subscribed).
    func send(_ updates: [StatusUpdate]) {
        guard !updates.isEmpty else { return }
        queuedUpdates.append(contentsOf: updates)
        flushUpdates()
    }

    /// Publishes or removes the service per the broadcasting setting and
    /// brings advertising in line with `controller.advertisingMode`.
    /// Idempotent: advertising restarts only when its payload changes.
    func refreshAdvertising() {
        guard bluetooth == .poweredOn else { return }
        syncService()
        let desired = isServiceAdded ? desiredAdvertisement() : nil
        guard desired != advertisement else { return }
        if advertisement != nil { manager.stopAdvertising() }
        advertisement = desired
        if let desired {
            manager.startAdvertising(desired.data)
            Self.log.info("Advertising \(desired.uuid, privacy: .public), name: \(desired.localName != nil)")
        } else {
            Self.log.info("Advertising stopped")
        }
    }

    // MARK: Service and advertising

    private func desiredAdvertisement() -> Advertisement? {
        switch controller.advertisingMode {
        case .off: nil
        case .pairing: Advertisement(uuid: WireUUID.pairingAdvertisement, localName: macName)
        case .reconnect: Advertisement(uuid: WireUUID.service, localName: nil)
        }
    }

    private func syncService() {
        let wanted = controller.isBroadcastEnabled
        if wanted && service == nil {
            publishService()
        } else if !wanted && service != nil {
            unpublishService()
        }
    }

    private func publishService() {
        let command = CBMutableCharacteristic(type: Self.commandUUID, properties: [.write],
                                              value: nil, permissions: [.writeable])
        let status = CBMutableCharacteristic(type: Self.statusUUID, properties: [.read, .notify],
                                             value: nil, permissions: [.readable])
        let macInfo = CBMutableCharacteristic(type: Self.macInfoUUID, properties: [.read],
                                              value: nil, permissions: [.readable])
        let service = CBMutableService(type: Self.serviceUUID, primary: true)
        service.characteristics = [command, status, macInfo]

        manager.removeAllServices()
        self.service = service
        statusCharacteristic = status
        isServiceAdded = false
        manager.add(service)
    }

    /// Broadcasting off. CoreBluetooth cannot drop a link from the peripheral
    /// side; without the service the watch's writes fail and it treats the
    /// link as lost.
    private func unpublishService() {
        if advertisement != nil { manager.stopAdvertising() }
        manager.removeAllServices()
        Self.log.info("Service removed")
        resetServiceState()
    }

    private func resetServiceState() {
        advertisement = nil
        service = nil
        statusCharacteristic = nil
        isServiceAdded = false
        subscribers.removeAll()
        queuedUpdates.removeAll()
    }

    // MARK: Retry

    /// Logs `failure` and calls `refreshAdvertising()` after the current
    /// backoff delay (2 s, doubling up to 30 s). A retry already pending
    /// covers this failure too.
    private func retryAfter(_ failure: String) {
        guard retryTask == nil else {
            Self.log.error("\(failure, privacy: .public); retry already pending")
            return
        }
        let delay = retryDelay
        Self.log.error("\(failure, privacy: .public); retry in \(delay.components.seconds) s")
        retryDelay = min(retryDelay * 2, Self.maxRetryDelay)
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            retryTask = nil
            refreshAdvertising()
        }
    }

    private func resetRetry() {
        retryTask?.cancel()
        retryTask = nil
        retryDelay = Self.initialRetryDelay
    }

    // MARK: Notifications

    private func flushUpdates() {
        guard let characteristic = statusCharacteristic, isServiceAdded else {
            queuedUpdates.removeAll()
            return
        }
        while let update = queuedUpdates.first {
            guard let central = subscribers[update.central] else {
                queuedUpdates.removeFirst()
                continue
            }
            let value = Data([update.status.rawValue])
            // false: transmit queue full; retried in peripheralManagerIsReady.
            guard manager.updateValue(value, for: characteristic, onSubscribedCentrals: [central]) else { return }
            queuedUpdates.removeFirst()
        }
    }

    // MARK: Delegate (main queue)

    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let state = peripheral.state
        MainActor.assumeIsolated { stateChanged(state) }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService,
                                       error: Error?) {
        let message = error?.localizedDescription
        nonisolated(unsafe) let service = service
        MainActor.assumeIsolated { serviceAdded(service, error: message) }
    }

    nonisolated func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        let message = error?.localizedDescription
        MainActor.assumeIsolated { advertisingStarted(error: message) }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                                       didSubscribeTo characteristic: CBCharacteristic) {
        // Only Status notifies; CBUUID is not Sendable, so compare here.
        guard characteristic.uuid == CBUUID(string: WireUUID.status) else { return }
        nonisolated(unsafe) let central = central
        MainActor.assumeIsolated { subscribed(central) }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral,
                                       didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard characteristic.uuid == CBUUID(string: WireUUID.status) else { return }
        let id = central.identifier
        MainActor.assumeIsolated { unsubscribed(id) }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        nonisolated(unsafe) let request = request
        MainActor.assumeIsolated { handleRead(request) }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager,
                                       didReceiveWrite requests: [CBATTRequest]) {
        nonisolated(unsafe) let requests = requests
        MainActor.assumeIsolated { handleWrites(requests) }
    }

    nonisolated func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        MainActor.assumeIsolated { flushUpdates() }
    }

    // MARK: Delegate handlers

    private func stateChanged(_ state: CBManagerState) {
        bluetooth = switch state {
        case .poweredOn: .poweredOn
        case .poweredOff: .poweredOff
        case .unauthorized: .unauthorized
        case .unsupported: .unsupported
        default: .unknown
        }
        Self.log.info("Bluetooth state \(state.rawValue)")
        resetRetry()  // power on republishes anyway; while off there is nothing to retry
        if bluetooth != .poweredOn {
            // The stack dropped services, advertising and links; no
            // unsubscribe callbacks will follow.
            var cancelled = false
            for id in subscribers.keys {
                if controller.centralUnsubscribed(id) { cancelled = true }
            }
            resetServiceState()
            if cancelled { onApprovalCancelled() }
        }
        refreshAdvertising()
        onChange()
    }

    private func serviceAdded(_ added: CBService, error: String?) {
        // By UUID: the callback need not pass back the same instance.
        guard added.uuid == Self.serviceUUID, service != nil else { return }  // removed meanwhile
        if let error {
            service = nil
            statusCharacteristic = nil
            retryAfter("Adding service failed: \(error)")
            return
        }
        Self.log.info("Service published")
        isServiceAdded = true
        retryDelay = Self.initialRetryDelay
        refreshAdvertising()
    }

    private func advertisingStarted(error: String?) {
        guard let error else {
            resetRetry()
            return
        }
        manager.stopAdvertising()
        advertisement = nil
        retryAfter("Advertising failed: \(error)")
    }

    private func subscribed(_ central: CBCentral) {
        Self.log.info("Central \(central.identifier, privacy: .public) subscribed")
        subscribers[central.identifier] = central
        manager.setDesiredConnectionLatency(.low, for: central)
        controller.centralSubscribed(central.identifier)
        onChange()
    }

    private func unsubscribed(_ id: UUID) {
        Self.log.info("Central \(id, privacy: .public) unsubscribed")
        subscribers[id] = nil
        queuedUpdates.removeAll { $0.central == id }
        if controller.centralUnsubscribed(id) { onApprovalCancelled() }
        onChange()
    }

    private func handleRead(_ request: CBATTRequest) {
        let value: Data
        switch request.characteristic.uuid {
        case Self.statusUUID:
            value = Data([controller.status(for: request.central.identifier).rawValue])
        case Self.macInfoUUID:
            value = WireCodec.encode(MacInfo(id: controller.macID, name: macName))
        default:
            manager.respond(to: request, withResult: .attributeNotFound)
            return
        }
        guard request.offset <= value.count else {
            manager.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = value.subdata(in: request.offset..<value.count)
        manager.respond(to: request, withResult: .success)
    }

    private func handleWrites(_ requests: [CBATTRequest]) {
        guard let first = requests.first else { return }
        var result: ATTResult = .success
        var updates: [StatusUpdate] = []
        var approvals: [ApprovalRequest] = []
        for request in requests {
            let central = request.central.identifier
            let write: WriteResult
            if request.characteristic.uuid != Self.commandUUID {
                write = WriteResult(att: .requestNotSupported)
            } else if request.offset != 0 {
                write = WriteResult(att: .invalidAttributeValueLength)
            } else {
                write = controller.handleWrite(from: central, data: request.value ?? Data())
            }
            Self.log.info("Write from \(central, privacy: .public): ATT \(write.att.rawValue)")
            if let action = write.action { onAction(action) }
            if result == .success { result = write.att }
            if let status = write.status { updates.append(StatusUpdate(central: central, status: status)) }
            if let approval = write.approvalRequest { approvals.append(approval) }
        }
        // CBATTError.Code is a non-frozen imported enum: init(rawValue:)
        // accepts any value, including the application codes 0x80/0x81.
        manager.respond(to: first, withResult: CBATTError.Code(rawValue: Int(result.rawValue)) ?? .unlikelyError)
        send(updates)
        approvals.forEach(onApprovalRequest)
        onChange()
    }
}
