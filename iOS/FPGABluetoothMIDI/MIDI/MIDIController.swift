// MIDIController.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import Foundation
import Combine
import CoreBluetooth
import os

/// Provides an interface to send and receive messages from a MIDI peripheral
///
/// The MIDI peripheral happens to be controlled using Bluetooth, but the details of this left as an implementation detail

final class MIDIController: NSObject,
    CBCentralManagerDelegate,
    CBPeripheralDelegate,
    ObservableObject
{
    enum State: Equatable {

        struct Interaction: Equatable {

            enum TransferStatus {

                case sent
                case acknowledged
            }

            let channel: Int
            var state: TransferStatus
        }

        struct Connection: Equatable {

            let peripheral: CBPeripheral
            let characteristic: CBCharacteristic
            var noteInteractions: [QualifiedNote: Interaction]
        }

        case readyToConnect

        case scanning
        case connecting(CBPeripheral)
        case connected(Connection)

        case unauthorized
        case off
        case unknown
    }

    private let manager: CBCentralManager
    private let maxChannels: Int

    private var sendQueue: [MIDIMessage] = []

    @Published var state: State = .unknown

    init(maxChannels: Int = 3) {
        self.maxChannels = maxChannels
        self.manager = CBCentralManager(delegate: nil, queue: nil, options: [:])

        super.init()

        self.manager.delegate = self
    }

    func scan() {
        guard state == .readyToConnect else { return }

        manager.scanForPeripherals(withServices: [Service.midiService.uuid], options: nil)
        state = .scanning
    }

    func updateActiveState(_ active: Bool, note: QualifiedNote) {
        guard case let .connected(connection) = state else { return }

        let allChannels = Set((0..<maxChannels).map { $0 })
        let activeChannels = Set(connection.noteInteractions.map { $0.value.channel })
        let availableChannels = allChannels.subtracting(activeChannels)
        let availableChannel = availableChannels.sorted().first

        var updatedConnection = connection

        if active, let availableChannel = availableChannel {
            queueMessage(.init(command: .noteOn, channel: availableChannel, note: note))

            var interaction: State.Interaction
            if let existingInteraction = updatedConnection.noteInteractions[note] {
                interaction = existingInteraction
                interaction.state = .sent
            } else {
                interaction = .init(channel: availableChannel, state: .sent)
            }

            updatedConnection.noteInteractions[note] = interaction
        } else if let interaction = connection.noteInteractions[note] {
            updatedConnection.noteInteractions.removeValue(forKey: note)
            queueMessage(.init(command: .noteOff, channel: interaction.channel, note: note))
        } else {
            os_log(.info, "Stopped note that isn't playing: %@", String(describing: note))
        }

        state = .connected(updatedConnection)
    }

    private func handleReceivedMessage(_ message: MIDIMessage) {
        guard case let .connected(connection) = state else { return }

        var updatedConnection = connection

        // A given channel can only play one note at a time
        updatedConnection.noteInteractions = connection.noteInteractions.filter { existingInteraction in
            existingInteraction.value.channel != message.channel
        }

        if message.command == .noteOn {
            updatedConnection.noteInteractions[message.note] = .init(channel: message.channel, state: .acknowledged)
        }

        state = .connected(updatedConnection)
    }

    private func queueMessage(_ message: MIDIMessage) {
        guard case let .connected(connection) = state else { return }

        if connection.peripheral.canSendWriteWithoutResponse {
            sendMessage(message)
        } else {
            sendQueue.append(message)
        }
    }

    private func sendMessage(_ message: MIDIMessage) {
        guard case let .connected(connection) = state else { return }

        connection.peripheral.writeValue(
            message.serialized,
            for: connection.characteristic,
            type: .withoutResponse
        )

        os_log(.info, "Sent MIDI message: %@", message.serialized.hexFormatted)
    }

    private func connect(to peripheral: CBPeripheral) {
        state = .connecting(peripheral)
        manager.connect(peripheral, options: nil)
    }

    private func didSucceed(accordingTo error: Error?, task attemptedTask: String) -> Bool {
        if let error = error {
            os_log(.error, "Failed during task: %@, error: %@",
                   attemptedTask, error.localizedDescription)
            return false
        } else {
            return true
        }
    }

    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let newState = central.state

        switch (state, newState) {
        case (.connected, .poweredOn), (.connected, .unknown):
            break
        default:
            state = newState.connectionState
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        os_log("Discovered peripheral with data: %@", advertisementData)

        central.stopScan()
        connect(to: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        os_log(.error, "Failed to connect with error: %@", error?.localizedDescription ?? "(no error)")

        // Simplfy default to retrying the connection regardless of cause
        connect(to: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("Connected to: %@", peripheral)

        peripheral.delegate = self
        peripheral.discoverServices([Service.midiService.uuid])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log(.error, "Disconnected with error: %@", error?.localizedDescription ?? "(no error)")
        state = central.state.connectionState
    }

    // MARK: CBPeripheralManagerDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard didSucceed(accordingTo: error, task: "service discovery") else { return }
        guard let services = peripheral.services else {
            os_log(.error, "Expected peripheral to have at least one service")
            return
        }
        guard let service = services.first(where: { $0.uuid == Service.midiService.uuid }) else {
            os_log(.error, "Expected peripheral to have MIDI service")
            return
        }

        peripheral.discoverCharacteristics(Service.midiService.allCharacteristicUUIDs, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let failureAction = {
            self.manager.cancelPeripheralConnection(peripheral)
        }

        guard didSucceed(accordingTo: error, task: "characteristic discovery") else {
            failureAction(); return
        }
        guard let characteristic = service.characteristic(modelledBy: .midiCharacteristic) else {
            failureAction(); return
        }

        state = .connected(
            .init(
                peripheral: peripheral,
                characteristic: characteristic,
                noteInteractions: [:]
            )
        )

        peripheral.setNotifyValue(true, for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            os_log(.error, "Failed to enable characteristic notifications: %@", error.localizedDescription)
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        guard !sendQueue.isEmpty else { return }

        sendMessage(sendQueue.removeFirst())
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard didSucceed(accordingTo: error, task: "characteristic notifying") else { return }
        guard case .connected = state else { return }
        guard let midiData = characteristic.value else {
            os_log(.error, "Expected characterisic to have data")
            return
        }
        guard let midiMessage = MIDIMessage(serializedMessage: midiData) else {
            os_log(.error, "Expected data to be deserializable to MIDIMessage")
            return
        }

        handleReceivedMessage(midiMessage)

        os_log("Characteristic value updated: %@", midiData.hexFormatted)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        os_log("Characteristic value written successfully: %@", characteristic.value?.hexFormatted ?? "(no data)")
    }
}

private struct Service {

    static let midiService = Service(
        uuid: CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700"),
        characteristics: [.midiCharacteristic]
    )

    let uuid: CBUUID
    let characteristics: [Characteristic]

    var allCharacteristicUUIDs: [CBUUID] {
        return characteristics.map { $0.uuid }
    }
}

private struct Characteristic {

    static let midiCharacteristic = Characteristic(
        name: "MIDI I/O",
        uuid: CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3"),
        expectedProperties: [.read, .write, .notify]
    )

    let name: String
    let uuid: CBUUID
    let expectedProperties: CBCharacteristicProperties
}

private extension CBService {

    func characteristic(modelledBy model: Characteristic) -> CBCharacteristic? {
        let characteristic = characteristics?.first { characteristic in
            characteristic.uuid == model.uuid &&
            characteristic.properties.isSuperset(of: model.expectedProperties)
        }

        if let characteristic = characteristic {
            return characteristic
        } else {
            os_log(.error, "No matching CBCharacteristic found for model: %@", model.name)
            return nil
        }
    }
}

private extension CBManagerState {

    var connectionState: MIDIController.State {
        switch self {
        case .poweredOn:
            return .readyToConnect
        case .poweredOff:
            return .off
        case .unauthorized:
            return .unauthorized
        case .resetting, .unsupported, .unknown:
            fallthrough
        @unknown default:
            return .unknown
        }
    }
}
