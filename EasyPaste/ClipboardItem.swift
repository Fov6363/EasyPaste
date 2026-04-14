//
//  ClipboardItem.swift
//  EasyPaste
//
//  Created by YuanYuan on 2026/3/25.
//

import Foundation

struct ClipboardItem: Identifiable, Codable, Sendable {
    let id: UUID
    let text: String
    let createdAt: Date
    let normalizedText: String
    let compactText: String

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.normalizedText = Self.normalizeForSearch(text, preserveWhitespace: true)
        self.compactText = Self.normalizeForSearch(text, preserveWhitespace: false)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let text = try container.decode(String.self, forKey: .text)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)

        self.init(id: id, text: text, createdAt: createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(createdAt, forKey: .createdAt)
    }

    nonisolated func matches(query: String) -> Bool {
        let normalizedQuery = Self.normalizeForSearch(query, preserveWhitespace: true)
        let compactQuery = Self.normalizeForSearch(query, preserveWhitespace: false)

        guard !compactQuery.isEmpty else {
            return true
        }

        if compactText.contains(compactQuery) {
            return true
        }

        let terms = normalizedQuery.split(separator: " ").map(String.init)
        guard !terms.isEmpty else {
            return true
        }

        return terms.allSatisfy { normalizedText.contains($0) || compactText.contains($0.replacingOccurrences(of: " ", with: "")) }
    }

    nonisolated private static func normalizeForSearch(_ value: String, preserveWhitespace: Bool) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)

        if preserveWhitespace {
            let collapsed = folded.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return folded.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }
}
