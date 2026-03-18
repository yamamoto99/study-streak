//
//  StudyCategory.swift
//  StudyStreak
//
//  Created by Masato Yamamoto on 2026/03/13.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class StudyCategory {
    var id: UUID
    var name: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, colorHex: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    var labelColor: Color {
        StudyCategoryColorOption.color(for: colorHex)
    }
}

struct StudyCategoryColorOption: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let hex: String

    var color: Color {
        Self.color(for: hex)
    }

    static let allOptions: [StudyCategoryColorOption] = [
        StudyCategoryColorOption(name: "赤", hex: "#E85D75"),
        StudyCategoryColorOption(name: "青", hex: "#4C7DFF"),
        StudyCategoryColorOption(name: "緑", hex: "#2DAA72"),
        StudyCategoryColorOption(name: "オレンジ", hex: "#F08C3A"),
        StudyCategoryColorOption(name: "ピンク", hex: "#E76FAD"),
        StudyCategoryColorOption(name: "紫", hex: "#8B5CF6"),
        StudyCategoryColorOption(name: "グレー", hex: "#6B7280")
    ]

    static let defaultOption = allOptions[0]

    static func color(for hex: String) -> Color {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 6, let value = Int(sanitized, radix: 16) else {
            return .accentColor
        }

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        return Color(red: red, green: green, blue: blue)
    }
}
