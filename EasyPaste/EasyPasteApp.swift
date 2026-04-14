//
//  EasyPasteApp.swift
//  EasyPaste
//
//  Created by YuanYuan on 2026/3/21.
//

import SwiftUI

@main
struct EasyPasteApp: App {
    @StateObject private var store: ClipboardStore
    @StateObject private var coordinator: AppCoordinator

    init() {
        let store = ClipboardStore()
        _store = StateObject(wrappedValue: store)
        _coordinator = StateObject(wrappedValue: AppCoordinator(store: store))
    }

    var body: some Scene {
        MenuBarExtra("EasyPaste", systemImage: "doc.on.clipboard") {
            MenuBarContentView(store: store, coordinator: coordinator)
        }
    }
}
