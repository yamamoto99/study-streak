//
//  StudyStreakWidget.swift
//  StudyStreakWidget
//
//  Created by Masato Yamamoto on 2026/03/16.
//

import SwiftUI
import WidgetKit

private let widgetSnapshotKey = "study_widget_snapshot_v1"
private let widgetSuiteName = "group.com.yamamoto99.StudyStreak"

struct StudyWidgetSnapshot: Codable {
    let generatedAt: Date
    let todayTotal: TimeInterval
    let totalTotal: TimeInterval
    let weekTotal: TimeInterval
    let streakDays: Int
    let dailyTotals: [TimeInterval]
}

struct StudyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: StudyWidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StudyWidgetEntry {
        StudyWidgetEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StudyWidgetEntry) -> Void) {
        completion(StudyWidgetEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudyWidgetEntry>) -> Void) {
        let now = Date()
        let entry = StudyWidgetEntry(date: now, snapshot: loadSnapshot())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadSnapshot() -> StudyWidgetSnapshot {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: widgetSuiteName) != nil,
              let defaults = UserDefaults(suiteName: widgetSuiteName) else {
            return .placeholder
        }

        guard let data = defaults.data(forKey: widgetSnapshotKey),
              let snapshot = try? JSONDecoder().decode(StudyWidgetSnapshot.self, from: data) else {
            return .placeholder
        }
        return snapshot
    }
}

struct StudyStreakWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StudyWidgetEntry

    var body: some View {
        if family == .systemSmall {
            smallLayout
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            mediumLayout
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var smallLayout: some View {
        VStack(spacing: 8) {
            Text("Current Streak")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            StreakRing(days: entry.snapshot.streakDays, ringSize: 94)
        }
        .padding(12)
    }

    private var mediumLayout: some View {
        HStack(spacing: 6) {
            sideMetric(title: "Total", value: compactDuration(entry.snapshot.totalTotal))
                .frame(width: 86)

            VStack(spacing: 10) {
                Spacer(minLength: 0)
                Text("Current Streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                StreakRing(days: entry.snapshot.streakDays, ringSize: 90)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            sideMetric(title: "Today", value: compactDuration(entry.snapshot.todayTotal))
                .frame(width: 86)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxHeight: .infinity)
    }

    private func sideMetric(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Spacer(minLength: 0)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.75)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    private func compactDuration(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }
        return String(format: "%dm", minutes)
    }

}

private struct StreakRing: View {
    let days: Int
    let ringSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 5)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Color.orange.opacity(0.95), Color.yellow.opacity(0.95), Color.orange.opacity(0.75)]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)

            VStack(spacing: 0) {
                Text("\(days)")
                    .font(.system(size: ringSize * 0.32, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text("days")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
    }

    private var progress: CGFloat {
        // 30日でリング1周の見た目。上限後は満タン表示。
        CGFloat(days) / 30.0
    }
}

struct StudyStreakWidget: Widget {
    let kind: String = "StudyStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(macOS 14.0, *) {
                StudyStreakWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [
                                Color(red: 0.10, green: 0.13, blue: 0.19),
                                Color(red: 0.11, green: 0.10, blue: 0.18),
                                Color(red: 0.08, green: 0.12, blue: 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else {
                StudyStreakWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Study Streak")
        .description("現在の連続学習日数と学習時間を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private extension StudyWidgetSnapshot {
    static var placeholder: StudyWidgetSnapshot {
        StudyWidgetSnapshot(
            generatedAt: Date(),
            todayTotal: 42 * 60,
            totalTotal: 42 * 3600,
            weekTotal: 5 * 3600 + 20 * 60,
            streakDays: 16,
            dailyTotals: [1200, 1800, 600, 2400, 3000, 900, 2520]
        )
    }
}
