//
//  ClipboardStore.swift
//  EasyPaste
//
//  Created by YuanYuan on 2026/3/25.
//

import AppKit
import Combine
import SwiftUI

class ClipboardStore: ObservableObject {
    @Published var clipboardText: String = ""
    @Published var history: [ClipboardItem] = []
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    private var storageKey = "clipboard.history"

    init() {
        loadHistory()
        loadClipboardText()
        if clipboardText != "" {
            appendToHistory(clipboardText)
        }
        startMonitoringClipboard()
    }

    deinit {
        stopMonitoringClipboard()
    }

    func copyHistoryItem(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)

        lastChangeCount = pasteboard.changeCount
        clipboardText = item.text
    }

    private func startMonitoringClipboard() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let pasteboard = NSPasteboard.general
            guard pasteboard.changeCount != self.lastChangeCount else { return }

            self.lastChangeCount = pasteboard.changeCount
            self.loadClipboardText()
            self.appendToHistory(self.clipboardText)
        }
    }

    private func stopMonitoringClipboard() {
        timer?.invalidate()
        timer = nil
    }

    func loadClipboardText() {
        let pasteboard = NSPasteboard.general
        clipboardText = pasteboard.string(forType: .string) ?? ""
    }

    func appendToHistory(_ text: String) {
        if text.isEmpty {
            return
        }

        if history.last?.text == text {
            return
        }

        let ci = ClipboardItem(text: text, createdAt: Date.now)
        history.append(ci)

        if history.count > 300 {
            // need slice
            history = Array(history.suffix(200))
        }

        saveHistory()
    }

    private func saveHistory() {
        let encoder = JSONEncoder()
        if let jsonData = try? encoder.encode(history) {
            UserDefaults.standard.set(jsonData, forKey: storageKey)
        }
    }

    private func loadHistory() {
        if let savedData = UserDefaults.standard.data(forKey: storageKey) {
            let decoder = JSONDecoder()

            if let history = try? decoder.decode([ClipboardItem].self, from: savedData) {
                self.history = history
            }
        }
    }
}
