// PianoView.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import SwiftUI

/// Interactive "piano" view that accepts user input and can also highlight a given set of keys
///
/// One octave of keys is displayed and more can be laying them out horizontally

struct PianoView: View {

    struct ViewModel {

        typealias NoteHandler = (_ key: QualifiedNote, _ on: Bool) -> Void

        let octave: Int
        let highlightedNotes: [QualifiedNote: UIColor]
        let noteUpdateHandler: NoteHandler
    }

    private struct SharpPlacement {

        let note: Note
        let position: Int
    }

    private let sharpWidthRatio: CGFloat = 0.75
    private let sharpHeightRatio: CGFloat = 0.65

    private let sharpPlacement: [SharpPlacement] = [
        .init(note: .cSharp, position: 1), .init(note: .dSharp, position: 2),
        .init(note: .fSharp, position: 4), .init(note: .gSharp, position: 5), .init(note: .aSharp, position: 6)
    ]

    let viewModel: ViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                let keyWidth = geo.size.width / CGFloat(Note.naturals.count)
                HStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/, spacing: 0) {
                    ForEach(Note.naturals) { key in
                        let qualifiedNote = key.qualified(withOctave: viewModel.octave)
                        Rectangle()
                            .fill(viewModel.highlightedNotes[qualifiedNote].map { Color($0) } ?? Color.white)
                            .border(Color.black, width: 2)
                            .modifier(OnTouchGestureModifier(viewModel: viewModel, key: qualifiedNote))
                    }
                }
                ZStack {
                    let sharpHeight = geo.size.height * sharpHeightRatio
                    let sharpWidth = keyWidth * sharpWidthRatio
                    ForEach(sharpPlacement, id: \.note) { placement in
                        let qualifiedNote = placement.note.qualified(withOctave: viewModel.octave)
                        Rectangle()
                            .fill(viewModel.highlightedNotes[qualifiedNote].map { Color($0) } ?? Color.black)
                            .frame(width: sharpWidth, height: sharpHeight)
                            .position(x: keyWidth * CGFloat(placement.position), y: sharpHeight / 2)
                            .modifier(OnTouchGestureModifier(viewModel: viewModel, key: qualifiedNote))
                    }
                }
            }
        }
        .aspectRatio(1.1, contentMode: .fit)
    }
}

private extension OnTouchGestureModifier {

    init(viewModel: PianoView.ViewModel, key: QualifiedNote) {
        self.init() { touchDown in
            viewModel.noteUpdateHandler(key, touchDown)
        }
    }
}

struct PianoView_Previews: PreviewProvider {
    
    static var previews: some View {
        PianoView(viewModel: .placeholder)
            .preferredColorScheme(.dark)
    }
}

extension PianoView.ViewModel {

    static let placeholder = Self(
        octave: 0,
        highlightedNotes: [
            .init(note: .c, octave: 0): .red,
            .init(note: .fSharp, octave: 0): .red
        ],
        noteUpdateHandler: { _,_ in }
    )
}
