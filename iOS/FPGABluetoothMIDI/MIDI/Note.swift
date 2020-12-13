// Note.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import Foundation

/// Representation of a music note that isn't qualified with an octave

enum Note: Int {

    static let naturals: [Note] = [.c, .d, .e, .f, .g, .a, .b]

    case c = 0, cSharp
    case d, dSharp
    case e
    case f, fSharp
    case g, gSharp
    case a, aSharp
    case b
}

extension Note: Identifiable {

    var id: Int {
        return self.rawValue
    }
}

extension Note {

    func qualified(withOctave octave: Int) -> QualifiedNote {
        return QualifiedNote(note: self, octave: octave)
    }
}
