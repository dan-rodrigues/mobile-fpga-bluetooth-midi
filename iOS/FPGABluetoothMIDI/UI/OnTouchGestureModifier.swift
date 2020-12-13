// OnTouchGestureModifier.swift
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

import SwiftUI

struct OnTouchGestureModifier: ViewModifier {

    let handler: (_ touchDown: Bool) -> Void

    @State private var isTouchingDown = false

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !self.isTouchingDown {
                        self.isTouchingDown = true
                        self.handler(true)
                    }
                }
                .onEnded { _ in
                    self.isTouchingDown = false
                    self.handler(false)
                })
    }
}
