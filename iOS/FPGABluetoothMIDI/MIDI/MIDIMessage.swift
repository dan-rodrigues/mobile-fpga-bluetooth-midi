// MIDIMessage.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import Foundation
import os

/// Encapsulates a single BLE MIDI message
///
/// It's possible for MIDI devices to send multiple messages in one packet but for this demo, 1 per packet is assumed

struct MIDIMessage {

    enum Command {

        case noteOn
        case noteOff
    }

    static let fixedVelocity: UInt8 = 0x7f;

    let command: Command
    let channel: Int
    let note: QualifiedNote

    private var midiNote: UInt8 {
        return UInt8(note.note.rawValue + note.octave * 12)
    }
}

extension MIDIMessage {

    init?(serializedMessage data: Data) {
        guard data.count == 5 else {
            os_log(.error, "Expected serialized MIDIMessage to be 5 bytes, got: %d", data.count)
            return nil
        }

        let message = data.subdata(in: (2..<5))

        switch message[0] & 0xf0 {
        case 0x90:
            self.command = .noteOn
        case 0x80:
            self.command = .noteOff
        default:
            os_log(.error, "Unrecognized MIDI command: %@", message[0])
            return nil
        }

        self.channel = Int(message[0] & 0x0f)

        let midiNote = Int(message[1] % 12)
        let octave = Int(message[1] / 12)

        guard let note = Note(rawValue: midiNote) else {
            os_log(.error, "Out of bounds MIDI note: %@", midiNote)
            return nil
        }

        self.note = QualifiedNote(note: note, octave: octave)

        // (MIDI velocity is ignored for now)
    }

    var serialized: Data {
        // The BLE MIDI timestamp and header is ignored and always assumed to be 0x80
        let header: [UInt8] = [0x80, 0x80]

        switch command {
        case .noteOn:
            return .init(header + [UInt8(0x90 | channel), midiNote, Self.fixedVelocity])
        case .noteOff:
            return .init(header + [UInt8(0x80 | channel), midiNote, Self.fixedVelocity])
        }
    }
}
