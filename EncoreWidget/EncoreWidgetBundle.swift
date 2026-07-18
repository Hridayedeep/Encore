//
//  EncoreWidgetBundle.swift
//  EncoreWidget — the extension entry point (see claude.md §10.4, §10.5)
//
//  Hosts BOTH the home/lock-screen widget and the Live Activity. Min deployment
//  iOS 26, so no availability guards needed.
//

import WidgetKit
import SwiftUI

@main
struct EncoreWidgetBundle: WidgetBundle {
    var body: some Widget {
        EncoreHomeWidget()
        EncoreLiveActivity()
    }
}
