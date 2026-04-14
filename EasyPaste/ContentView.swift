//
//  ContentView.swift
//  EasyPaste
//
//  Created by YuanYuan on 2026/3/21.
//

import AppKit
import OSLog
import SwiftUI

struct ContentView: View {
    private static let logger = Logger(subsystem: "com.yy.EasyPaste", category: "Search")

    @ObservedObject var store: ClipboardStore
    @ObservedObject var panelState: PanelState
    @ObservedObject var coordinator: AppCoordinator
    @State private var selectedItemID: ClipboardItem.ID?
    @State private var searchText = ""
    @State private var filteredItems: [ClipboardItem] = []
    @FocusState private var isSearchFocused: Bool

    let onSelect: (ClipboardItem) -> Void
    let onClose: () -> Void

    private var reversedItems: [ClipboardItem] {
        Array(store.history.reversed())
    }

    private var historyItemIDs: [ClipboardItem.ID] {
        reversedItems.map(\.id)
    }

    private var filteredListIdentity: String {
        let ids = filteredItems.map(\.id.uuidString).joined(separator: ",")
        return "\(searchText)|\(ids)"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                backgroundView

                VStack(alignment: .leading, spacing: 12) {
                    headerView(historyCount: filteredItems.count, totalCount: reversedItems.count)
                    if !coordinator.isAccessibilityTrusted {
                        accessibilityBanner
                    }
                    searchBar(resultCount: filteredItems.count)
                    historyList(items: filteredItems)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(16)
            }
            .frame(width: 468, height: 640)
            .background {
                LocalKeyEventMonitor { event in
                    handleKeyEvent(event, items: filteredItems)
                }
            }
            .focusable()
            .onMoveCommand { direction in
                guard !filteredItems.isEmpty else {
                    selectedItemID = nil
                    return
                }

                switch direction {
                case .up:
                    moveSelection(step: -1, items: filteredItems)
                case .down:
                    moveSelection(step: 1, items: filteredItems)
                default:
                    break
                }
            }
            .onChange(of: selectedItemID) { _, newValue in
                guard let id = newValue else { return }
                withAnimation(.snappy(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .background {
                Button("") {
                    copySelectedItem(from: filteredItems)
                }
                .keyboardShortcut(.defaultAction)
                .hidden()
            }
            .background {
                Button("") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
                .hidden()
            }
            .onAppear {
                focusSearchField(with: reversedItems.count)
                refreshFilteredItems(resetSelection: true)
            }
            .onChange(of: searchText) { _, _ in
                refreshFilteredItems(resetSelection: true)
            }
            .onChange(of: historyItemIDs) { _, _ in
                refreshFilteredItems(resetSelection: false)
            }
            .onChange(of: panelState.focusToken) { _, _ in
                focusSearchField(with: reversedItems.count)
                refreshFilteredItems(resetSelection: true)
            }
        }
    }

    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    EasyPasteTheme.cream,
                    Color.white,
                    EasyPasteTheme.mist
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(EasyPasteTheme.accent.opacity(0.16))
                .frame(width: 240, height: 240)
                .offset(x: 170, y: -210)

            Circle()
                .fill(EasyPasteTheme.accentSoft.opacity(0.35))
                .frame(width: 180, height: 180)
                .offset(x: -180, y: 230)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(EasyPasteTheme.line, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 28, y: 14)
    }

    private func headerView(historyCount: Int, totalCount: Int) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("EasyPaste")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.ink)

                Text("快速找回剪贴板历史，按回车立即回填")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.cocoa)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                shortcutChip
                Text("\(historyCount)/\(totalCount) 条")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.muted)
            }
        }
    }

    private var accessibilityBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(EasyPasteTheme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("自动回填需要键盘事件发送权限")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.ink)

                Text("未授权时只能复制到剪贴板，无法自动执行粘贴。")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.cocoa)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Button("开启权限") {
                coordinator.requestAccessibilityPermission()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(EasyPasteTheme.accent, in: Capsule())
        }
        .padding(12)
        .background(cardBackground(highlighted: true))
    }

    private func searchBar(resultCount: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(EasyPasteTheme.accent)

            TextField("搜索历史记录", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(EasyPasteTheme.ink)
                .focused($isSearchFocused)

            Spacer(minLength: 0)

            Text(resultCount == 0 ? "无结果" : "\(resultCount) 条结果")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(EasyPasteTheme.cocoa)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(cardBackground())
    }

    private func historyList(items: [ClipboardItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("历史记录", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.ink)

                Spacer()

                Text("上下选择，回车回填")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.muted)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if items.isEmpty {
                        emptyState
                    } else {
                        ForEach(items) { item in
                            HistoryItemCard(
                                item: item,
                                isSelected: selectedItemID == item.id,
                                onTap: {
                                    selectItem(item)
                                }
                            )
                            .id(item.id)
                        }
                    }
                }
                .id(filteredListIdentity)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .scrollIndicators(.hidden)
        }
        .padding(14)
        .background(cardBackground())
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(EasyPasteTheme.accent.opacity(0.7))

            Text("没有匹配结果")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(EasyPasteTheme.ink)

            Text("换个关键词试试，或者先复制一些文本进来。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(EasyPasteTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.52))
        )
    }

    private func cardBackground(highlighted: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(highlighted ? EasyPasteTheme.accent.opacity(0.35) : EasyPasteTheme.line, lineWidth: 1)
            )
    }

    private var shortcutChip: some View {
        Text(coordinator.shortcutDisplayText)
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(EasyPasteTheme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.8), in: Capsule())
        .overlay(
            Capsule().stroke(EasyPasteTheme.line, lineWidth: 1)
        )
    }

    private func copySelectedItem(from items: [ClipboardItem]) {
        guard let selectedItemID,
              let item = items.first(where: { $0.id == selectedItemID }) else { return }

        selectItem(item)
    }

    private func selectItem(_ item: ClipboardItem) {
        selectedItemID = item.id
        onSelect(item)
    }

    private func focusSearchField(with itemCount: Int) {
        searchText = ""
        selectedItemID = nil
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func refreshFilteredItems(resetSelection: Bool) {
        let sourceItems = reversedItems
        let query = searchText
        let filtered = query.isEmpty ? sourceItems : sourceItems.filter { $0.matches(query: query) }
        logSearchResults(query: query, items: filtered, resetSelection: resetSelection)
        applyFilteredItems(filtered, resetSelection: resetSelection)
    }

    private func applyFilteredItems(_ items: [ClipboardItem], resetSelection: Bool) {
        filteredItems = items

        if resetSelection {
            selectedItemID = items.first?.id
            logSelectionState(itemCount: items.count)
            return
        }

        guard !items.isEmpty else {
            selectedItemID = nil
            logSelectionState(itemCount: items.count)
            return
        }

        guard let selectedItemID else {
            self.selectedItemID = items.first?.id
            logSelectionState(itemCount: items.count)
            return
        }

        if items.contains(where: { $0.id == selectedItemID }) {
            self.selectedItemID = selectedItemID
        } else {
            self.selectedItemID = items.first?.id
        }
        logSelectionState(itemCount: items.count)
    }

    private func logSearchResults(query: String, items: [ClipboardItem], resetSelection: Bool) {
        let normalizedQuery = query.replacingOccurrences(of: "\n", with: "\\n")
        Self.logger.notice("search query=\(normalizedQuery, privacy: .public) resultCount=\(items.count, privacy: .public) resetSelection=\(resetSelection, privacy: .public)")

        for (index, item) in items.prefix(8).enumerated() {
            Self.logger.notice("search result index=\(index, privacy: .public) id=\(item.id.uuidString, privacy: .public) preview=\(previewText(for: item.text), privacy: .public)")
        }

        if items.count > 8 {
            Self.logger.notice("search results truncated omitted=\(items.count - 8, privacy: .public)")
        }
    }

    private func logSelectionState(itemCount: Int) {
        Self.logger.notice("search selection selectedItemID=\(selectedItemID?.uuidString ?? "nil", privacy: .public) itemCount=\(itemCount, privacy: .public)")
    }

    private func previewText(for text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = singleLine.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(40))
    }

    private func handleKeyEvent(_ event: NSEvent, items: [ClipboardItem]) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard modifiers.intersection(blockedModifiers).isEmpty else {
            return false
        }

        switch Int(event.keyCode) {
        case 125:
            moveSelection(step: 1, items: items)
            return true
        case 126:
            moveSelection(step: -1, items: items)
            return true
        case 36, 76:
            copySelectedItem(from: items)
            return true
        case 53:
            onClose()
            return true
        default:
            return false
        }
    }

    private func moveSelection(step: Int, items: [ClipboardItem]) {
        guard !items.isEmpty else {
            selectedItemID = nil
            return
        }

        let currentIndex = items.firstIndex(where: { $0.id == selectedItemID }) ?? 0
        let nextIndex = min(max(currentIndex + step, 0), items.count - 1)
        selectedItemID = items[nextIndex].id
    }

}

private struct HistoryItemCard: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? EasyPasteTheme.accent : EasyPasteTheme.cocoa)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.62))
                        )

                    Spacer()

                    Image(systemName: isSelected ? "arrow.turn.down.left" : "doc.on.doc")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? EasyPasteTheme.accent : EasyPasteTheme.muted)
                }

                Text(item.text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(background)
            .overlay(border)
            .shadow(color: shadowColor, radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                isSelected
                    ? LinearGradient(
                        colors: [Color.white.opacity(0.96), EasyPasteTheme.accentSoft.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color.white.opacity(0.82), Color.white.opacity(0.56)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                isSelected ? EasyPasteTheme.accent.opacity(0.75) : Color.white.opacity(0.65),
                lineWidth: isSelected ? 1.6 : 1
            )
    }

    private var shadowColor: Color {
        isSelected ? EasyPasteTheme.accent.opacity(0.18) : Color.black.opacity(0.06)
    }
}

#Preview {
    let store = ClipboardStore()
    ContentView(
        store: store,
        panelState: PanelState(),
        coordinator: AppCoordinator(store: store),
        onSelect: { _ in },
        onClose: {}
    )
}
