//
//  StudySession.swift
//  StudyStreak
//
//  Created by Masato Yamamoto on 2026/03/13.
//

import Foundation
import SwiftData

@Model
final class StudySession {
    var id: UUID
    var category: StudyCategory
    var startAt: Date
    var endAt: Date?

    init(id: UUID = UUID(), category: StudyCategory, startAt: Date, endAt: Date? = nil) {
        self.id = id
        self.category = category
        self.startAt = startAt
        self.endAt = endAt
    }

    var duration: TimeInterval {
        duration(at: Date())
    }

    func duration(at now: Date) -> TimeInterval {
        max((endAt ?? now).timeIntervalSince(startAt), 0)
    }
}
