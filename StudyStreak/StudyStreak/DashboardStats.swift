//
//  DashboardStats.swift
//  StudyStreak
//
//  Created by Masato Yamamoto on 2026/03/13.
//

import Foundation
import SwiftUI

struct StudyWidgetSnapshot: Codable {
    let generatedAt: Date
    let todayTotal: TimeInterval
    let totalTotal: TimeInterval
    let weekTotal: TimeInterval
    let streakDays: Int
    let dailyTotals: [TimeInterval]
}

struct DashboardStats {
    struct DailyTrendItem: Identifiable {
        let id: String
        let date: Date
        let label: String
        let categoryName: String
        let color: Color
        let totalDuration: TimeInterval
        let isPlaceholder: Bool
    }

    struct CategoryBreakdownItem: Identifiable {
        let id: String
        let categoryName: String
        let color: Color
        let totalDuration: TimeInterval
    }

    let todayTotal: TimeInterval
    let weekTotal: TimeInterval
    let streakDays: Int
    let dailyTrend: [DailyTrendItem]
    let categoryBreakdown: [CategoryBreakdownItem]

    static func make(from sessions: [StudySession], now: Date, calendar: Calendar = .current) -> DashboardStats {
        let todayTotal = sessions
            .filter { calendar.isDateInToday($0.startAt) }
            .reduce(0) { $0 + $1.duration(at: now) }

        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekTotal = sessions
            .filter { session in
                guard let weekInterval else { return false }
                return weekInterval.contains(session.startAt)
            }
            .reduce(0) { $0 + $1.duration(at: now) }

        let streakDays = makeStreakDays(from: sessions, now: now, calendar: calendar)
        let dailyTrend = makeDailyTrend(from: sessions, now: now, calendar: calendar)

        var groupedDurations: [String: CategoryBreakdownItem] = [:]
        for session in sessions {
            let key = session.category.id.uuidString
            let nextDuration = (groupedDurations[key]?.totalDuration ?? 0) + session.duration(at: now)
            groupedDurations[key] = CategoryBreakdownItem(
                id: key,
                categoryName: session.category.name,
                color: session.category.labelColor,
                totalDuration: nextDuration
            )
        }

        let categoryBreakdown = groupedDurations.values.sorted { $0.totalDuration > $1.totalDuration }

        return DashboardStats(
            todayTotal: todayTotal,
            weekTotal: weekTotal,
            streakDays: streakDays,
            dailyTrend: dailyTrend,
            categoryBreakdown: categoryBreakdown
        )
    }

    static func makeStreakDays(from sessions: [StudySession], now: Date, calendar: Calendar) -> Int {
        let studiedDays = Set(
            sessions.compactMap { session in
                calendar.dateInterval(of: .day, for: session.startAt)?.start
            }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: now)

        while studiedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    static func makeWidgetSnapshot(from sessions: [StudySession], now: Date, calendar: Calendar = .current) -> StudyWidgetSnapshot {
        let stats = make(from: sessions, now: now, calendar: calendar)
        let dailyTotals = makeLast7DayTotals(from: sessions, now: now, calendar: calendar)
        let totalTotal = sessions.reduce(0) { $0 + $1.duration(at: now) }

        return StudyWidgetSnapshot(
            generatedAt: now,
            todayTotal: stats.todayTotal,
            totalTotal: totalTotal,
            weekTotal: stats.weekTotal,
            streakDays: stats.streakDays,
            dailyTotals: dailyTotals
        )
    }

    static func makeLast7DayTotals(from sessions: [StudySession], now: Date, calendar: Calendar) -> [TimeInterval] {
        (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: now),
                  let dayStart = calendar.dateInterval(of: .day, for: date)?.start else {
                return nil
            }

            return sessions
                .filter { calendar.isDate($0.startAt, inSameDayAs: dayStart) }
                .reduce(0) { $0 + $1.duration(at: now) }
        }
    }

    static func makeDailyTrend(from sessions: [StudySession], now: Date, calendar: Calendar) -> [DailyTrendItem] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"

        return (0..<7).flatMap { offset -> [DailyTrendItem] in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: now),
                  let dayStart = calendar.dateInterval(of: .day, for: date)?.start else {
                return []
            }

            let dailySessions = sessions
                .filter { calendar.isDate($0.startAt, inSameDayAs: dayStart) }

            var groupedDurations: [String: DailyTrendItem] = [:]
            for session in dailySessions {
                let key = session.category.id.uuidString
                let nextDuration = (groupedDurations[key]?.totalDuration ?? 0) + session.duration(at: now)
                groupedDurations[key] = DailyTrendItem(
                    id: "\(dayStart.timeIntervalSince1970)-\(key)",
                    date: dayStart,
                    label: formatter.string(from: dayStart),
                    categoryName: session.category.name,
                    color: session.category.labelColor,
                    totalDuration: nextDuration,
                    isPlaceholder: false
                )
            }

            if groupedDurations.isEmpty {
                return [
                    DailyTrendItem(
                        id: "\(dayStart.timeIntervalSince1970)-empty",
                        date: dayStart,
                        label: formatter.string(from: dayStart),
                        categoryName: "記録なし",
                        color: .clear,
                        totalDuration: 0,
                        isPlaceholder: true
                    )
                ]
            }

            return groupedDurations.values.sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.totalDuration > rhs.totalDuration
                }
                return lhs.date < rhs.date
            }
        }
    }

    static func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
