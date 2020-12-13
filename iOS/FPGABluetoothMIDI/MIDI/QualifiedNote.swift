// QualifiedNote.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import Foundation

/// Representation of a music note that is qualified with an octave

struct QualifiedNote: Hashable {

    let note: Note
    let octave: Int
}
