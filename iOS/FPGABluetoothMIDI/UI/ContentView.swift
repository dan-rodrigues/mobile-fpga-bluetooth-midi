// ContentView.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import SwiftUI

struct ContentView: View {

    struct ViewModel {

        typealias Handler = () -> Void
        typealias OctaveUpdateHandler = (_ updatedOctaveCount: Int) -> Void
        typealias NoteHandler = (_ key: QualifiedNote, _ on: Bool) -> Void

        let title: String
        let scanEnabled: Bool
        let connectedActionsEnabled: Bool
        let octaveUpdateActionsEnabled: Bool
        let octaveCount: Int

        let highlightedNotes: [QualifiedNote: UIColor]

        let scanHandler: Handler
        let noteUpdateHandler: NoteHandler
        let octaveCountUpdateHandler: OctaveUpdateHandler
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 0) {
                ForEach(0..<viewModel.octaveCount, id: \.self) { octave in
                    PianoView(viewModel: .init(contentViewModel: viewModel, octave: octave))
                }
            }
            .border(Color.black, width: 2)
            .padding([.top, .bottom], 2)

            Spacer()

            Text(viewModel.title)
            Button("Scan", action: viewModel.scanHandler)
                .disabled(!viewModel.scanEnabled)
                .padding(2)

            HStack {
                Button("-") {
                    guard viewModel.octaveCount > 1 else { return }
                    viewModel.octaveCountUpdateHandler(viewModel.octaveCount - 1)
                }
                .disabled(!viewModel.octaveUpdateActionsEnabled)

                Text("Octaves")

                Button("+") {
                    guard viewModel.octaveCount < 3 else { return }
                    viewModel.octaveCountUpdateHandler(viewModel.octaveCount + 1)
                }
                .disabled(!viewModel.octaveUpdateActionsEnabled)
            }
            .padding(.bottom)
        }
    }
}

struct ContentView_Previews: PreviewProvider {

    static var previews: some View {
        ContentView(viewModel: .placeholder)
            .preferredColorScheme(.dark)
    }
}

private extension PianoView.ViewModel {

    init(contentViewModel: ContentView.ViewModel, octave: Int) {
        self.octave = octave
        self.highlightedNotes = contentViewModel.highlightedNotes.filter { note, interaction in
            note.octave == octave
        }
        self.noteUpdateHandler = contentViewModel.noteUpdateHandler
    }
}

extension ContentView.ViewModel {

    static let placeholder = Self(
        title: "(Placeholder title)",
        scanEnabled: false,
        connectedActionsEnabled: false,
        octaveUpdateActionsEnabled: false,
        octaveCount: 3,
        highlightedNotes: [:],
        scanHandler: {},
        noteUpdateHandler: { _,_  in },
        octaveCountUpdateHandler: { _ in }
    )
}
