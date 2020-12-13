// ViewModelFactory.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import Foundation
import Combine
import UIKit
import os

/// Provides the observable source of truth to generate SwiftUI views.
///
/// The observable `viewModel` property can be used to automatically generate
/// views when the application state changes, whether it is change initiated by
/// this app or by the peripheral.
///
/// Details of how the state is generated, including peripheral management, is an
/// implementation detail.

final class ViewModelFactory: ObservableObject {

    private let peripheralController: MIDIController

    @Published private var octaveCount: Int = 3
    @Published var viewModel: ContentView.ViewModel = .placeholder
    private var cancellables = Set<AnyCancellable>()

    init(peripheralController: MIDIController = .init()) {
        self.peripheralController = peripheralController

        peripheralController.$state
            .combineLatest($octaveCount)
            .map { state, octaveCount in
                ContentView.ViewModel(
                    title: state.title,
                    scanEnabled: state == .readyToConnect,
                    connectedActionsEnabled: state.connected,
                    octaveUpdateActionsEnabled: true,
                    octaveCount: octaveCount,
                    highlightedNotes: state.highlightedKeys,
                    scanHandler: { [weak peripheralController] in
                        peripheralController?.scan()
                    },
                    noteUpdateHandler: { [weak peripheralController] key, on in
                        peripheralController?.updateActiveState(on, note: key)
                        os_log(.info, "User changed key: %@, on: %@", String(describing: key), String(describing: on))
                    },
                    octaveCountUpdateHandler: { [weak self] updatedOctaveCount in
                        self?.octaveCount = updatedOctaveCount
                    }
                )
            }
            .eraseToAnyPublisher()
            .assign(to: \.viewModel, on: self)
            .store(in: &cancellables)
    }
}

private extension MIDIController.State {

    var title: String {
        switch self {
        case .readyToConnect: return NSLocalizedString("Ready to scan", comment: "")
        case .off: return NSLocalizedString("Bluetooth is disabled", comment: "")
        case .unknown: return NSLocalizedString("Bluetooth in unknown state", comment: "")
        case .unauthorized: return NSLocalizedString("App not authorized to use Bluetooth", comment: "")
        case .connected: return NSLocalizedString("Connected", comment: "")
        case .connecting: return NSLocalizedString("Connecting...", comment: "")
        case .scanning: return NSLocalizedString("Scanning...", comment: "")
        }
    }

    var connected: Bool {
        if case .connected = self {
            return true
        } else {
            return false
        }
    }

    var highlightedKeys: [QualifiedNote: UIColor] {
        switch self {
        case let .connected(connection):
            return connection.noteInteractions.mapValues { state in
                state.state == .acknowledged ? .red : .gray
            }
        default:
            return [:]
        }
    }
}

