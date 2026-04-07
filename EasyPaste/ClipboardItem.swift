//
//  ClipboardItem.swift
//  EasyPaste
//
//  Created by YuanYuan on 2026/3/25.
//

import Foundation

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
    }
}
