// DataHexFormatting.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import Foundation

extension Data {

    var hexFormatted: String {
        map { String(format: "%2X", $0) }.joined(separator: ", ")
    }
}
