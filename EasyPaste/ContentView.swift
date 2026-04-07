//
//  ContentView.swift
//  EasyPaste
//
//  Created by YuanYuan on 2026/3/21.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ClipboardStore
    @State var selectedIndex: Int? = 0
    @State private var searchText = ""

    var body: some View {
        let reversedItems = Array(store.history.reversed())
        let filteredItems = searchText.isEmpty ? reversedItems : reversedItems.filter { item in
            item.text.localizedCaseInsensitiveContains(searchText)
        }

        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 12) {
                Text("当前剪切板内容").font(.headline)

                Text(self.store.clipboardText).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("搜索历史记录", text: $searchText).textFieldStyle(.roundedBorder)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            let isSelected = self.selectedIndex == index || (self.selectedIndex == nil && index == 0)
                            let borderColor: Color = isSelected ? .red : .gray

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.createdAt, style: .time).frame(width: 360, alignment: .leading).foregroundStyle(.gray)
                                Text(item.text).frame(width: 360, height: 40, alignment: .leading).padding(.top, 2)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                self.store.copyHistoryItem(item)
                            }
                            .padding(8).border(borderColor).id(index)
                        }
                    }
                }
            }
            .padding()
            .frame(width: 360, height: 480)
            .focusable()
            .onMoveCommand { direction in
                switch direction {
                case .up:
                    selectedIndex = max((selectedIndex ?? 0) - 1, 0)
                case .down:
                    selectedIndex = min((selectedIndex ?? 0) + 1, filteredItems.count - 1)
                default:
                    break
                }
            }.onChange(of: self.selectedIndex) { _, newValue in
                guard let index = newValue else { return }
                withAnimation {
                    proxy.scrollTo(index, anchor: .center)
                }
            }.background {
                Button("") {
                    guard let index = selectedIndex,
                          filteredItems.indices.contains(index) else { return }
                    store.copyHistoryItem(filteredItems[index])
                }
                .keyboardShortcut(.defaultAction)
                .hidden()
            }.onChange(of: self.searchText) { _, _ in
                selectedIndex = filteredItems.isEmpty ? nil : 0
            }
        }
    }
}

#Preview {
    ContentView(store: ClipboardStore())
}
