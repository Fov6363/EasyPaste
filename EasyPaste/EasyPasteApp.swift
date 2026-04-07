//
//  EasyPasteApp.swift
//  EasyPaste
//
//  Created by YuanYuan on 2026/3/21.
//

import SwiftUI

@main
struct EasyPasteApp: App {
    @StateObject private var store = ClipboardStore()

    var body: some Scene {
        MenuBarExtra("EasyPaste", systemImage: "doc.on.clipboard") {
            ContentView(store: self.store)
        }.menuBarExtraStyle(.window)
    }
}
