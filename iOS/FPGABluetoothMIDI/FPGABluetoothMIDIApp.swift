// FPGABluetoothMIDIApp.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import SwiftUI

@main
struct FPGABluetoothMIDIApp: App {

    @StateObject var viewModelFactory = ViewModelFactory()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModelFactory.viewModel)
        }
    }
}
