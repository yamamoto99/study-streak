//
//  ContentView.swift
//  StudyStreak
//
//  Created by Masato Yamamoto on 2026/03/13.
//

import Charts
import Combine
import SwiftData
import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

private enum StudyPage: String, CaseIterable, Identifiable {
    case session
    case categories
    case dashboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .session:
            "学習"
        case .categories:
            "カテゴリ"
        case .dashboard:
            "ダッシュボード"
        }
    }

    var systemImage: String {
        switch self {
        case .session:
            "play.circle"
        case .categories:
            "tag"
        case .dashboard:
            "chart.bar.xaxis"
        }
    }
}

struct ContentView: View {
    private static let widgetKind = "StudyStreakWidget"
    private static let widgetSnapshotKey = "study_widget_snapshot_v1"
    private static let widgetSuiteName = "group.com.yamamoto99.StudyStreak"

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyCategory.name) private var categories: [StudyCategory]
    @Query(sort: \StudySession.startAt, order: .reverse) private var sessions: [StudySession]

    @State private var selectedPage: StudyPage? = .session
    @State private var selectedCategoryID: UUID?
    @State private var newCategoryName = ""
    @State private var selectedColorHex = StudyCategoryColorOption.defaultOption.hex
    @State private var now = Date()
    @State private var categoryPendingDeletion: StudyCategory?
    @State private var sessionPendingDeletion: StudySession?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {}

    private var currentSession: StudySession? {
        sessions.first(where: { $0.endAt == nil })
    }

    private var selectedCategory: StudyCategory? {
        guard let selectedCategoryID else { return nil }
        return categories.first(where: { $0.id == selectedCategoryID })
    }

    private var effectiveCategory: StudyCategory? {
        currentSession?.category ?? selectedCategory
    }

    private var dashboardStats: DashboardStats {
        DashboardStats.make(from: sessions, now: now)
    }

    private var trendLegendItems: [(name: String, color: Color)] {
        dashboardStats.categoryBreakdown.map { ($0.categoryName, $0.color) }
    }

    private var dailyTrendLabels: [String] {
        var seen = Set<String>()
        return dashboardStats.dailyTrend.compactMap { item in
            guard seen.insert(item.label).inserted else { return nil }
            return item.label
        }
    }

    private var elapsedText: String {
        guard let currentSession else { return "00:00:00" }
        return DashboardStats.durationText(currentSession.duration(at: now))
    }

    private var elapsedCaption: String {
        guard let currentSession else { return "まだ学習を開始していません" }
        return "開始 \(currentSession.startAt.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
                .background(backgroundGradient)
        }
        .frame(minWidth: 980, minHeight: 680)
        .onAppear {
            syncSelectedCategory()
            persistWidgetSnapshot()
        }
        .onChange(of: categories.count) { _, _ in
            syncSelectedCategory()
        }
        .onChange(of: sessions.count) { _, _ in
            persistWidgetSnapshot()
        }
        .onReceive(timer) { date in
            now = date
        }
        .alert("カテゴリを削除しますか？", isPresented: isDeleteCategoryAlertPresented) {
            Button("削除", role: .destructive) {
                confirmDeleteCategory()
            }

            Button("キャンセル", role: .cancel) {
                self.categoryPendingDeletion = nil
            }
        } message: {
            if let pendingCategory = categoryPendingDeletion {
                Text("「\(pendingCategory.name)」と、そのカテゴリに紐づくセッションを削除します。")
            }
        }
        .alert("セッションを削除しますか？", isPresented: isDeleteSessionAlertPresented) {
            Button("削除", role: .destructive) {
                confirmDeleteSession()
            }

            Button("キャンセル", role: .cancel) {
                self.sessionPendingDeletion = nil
            }
        } message: {
            if let pendingSession = sessionPendingDeletion {
                Text("\(pendingSession.startAt.formatted(date: .abbreviated, time: .shortened)) の記録を削除します。")
            }
        }
    }

    private var sidebar: some View {
        List(StudyPage.allCases, selection: $selectedPage) { page in
            Label(page.title, systemImage: page.systemImage)
                .tag(page)
        }
        .navigationTitle("StudyStreak")
        .frame(minWidth: 200)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedPage ?? .session {
        case .session:
            sessionPage
        case .categories:
            categoryPage
        case .dashboard:
            dashboardPage
        }
    }

    private var sessionPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader(
                    title: "学習セッション",
                    subtitle: "今の学習をすぐ開始して、止めたらそのまま記録します。"
                )

                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("カテゴリ")
                            .font(.headline)

                        Picker("カテゴリ", selection: $selectedCategoryID) {
                            Text("カテゴリを選択").tag(Optional<UUID>.none)

                            ForEach(categories) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                        .disabled(currentSession != nil)
                        .frame(maxWidth: 280)

                        if let category = effectiveCategory {
                            categoryBadge(for: category)
                        } else {
                            Text("カテゴリを追加してから開始してください")
                                .foregroundStyle(.secondary)
                        }

                        Text(currentSession == nil ? "停止中" : "学習中")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: 260, alignment: .leading)

                    VStack(alignment: .center, spacing: 20) {
                        Text(elapsedText)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity)

                        Text(elapsedCaption)
                            .foregroundStyle(.secondary)

                        Button {
                            toggleStudy()
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: currentSession == nil ? "play.fill" : "stop.fill")
                                    .font(.system(size: 26, weight: .bold))

                                Text(currentSession == nil ? "勉強開始" : "勉強終了")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(actionButtonGradient)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(.white.opacity(0.08), lineWidth: 1)
                            )
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                        }
                        .buttonStyle(.plain)
                        .disabled(currentSession == nil && selectedCategory == nil)

                        Text(actionHintText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(panelBackground)
                }

                HStack(spacing: 16) {
                    summaryCard(title: "今日", value: DashboardStats.durationText(dashboardStats.todayTotal))
                    summaryCard(title: "今週", value: DashboardStats.durationText(dashboardStats.weekTotal))
                    summaryCard(title: "連続", value: "\(dashboardStats.streakDays)日")
                }
            }
            .padding(28)
        }
        .navigationTitle("学習")
    }

    private var categoryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader(
                    title: "カテゴリ管理",
                    subtitle: "よく使う学習テーマを色付きで登録します。"
                )

                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 18) {
                        TextField("名前", text: $newCategoryName)
                            .textFieldStyle(.roundedBorder)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("ラベルカラー")
                                .font(.headline)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                                ForEach(StudyCategoryColorOption.allOptions) { option in
                                    Button {
                                        selectedColorHex = option.hex
                                    } label: {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(option.color)
                                                .frame(width: 12, height: 12)

                                            Text(option.name)
                                                .font(.subheadline)

                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(selectedColorHex == option.hex ? option.color.opacity(0.18) : Color.white.opacity(0.04))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(selectedColorHex == option.hex ? option.color : .white.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button("カテゴリ追加") {
                            addCategory()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .frame(maxWidth: 420, alignment: .leading)
                    .padding(24)
                    .background(panelBackground)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("登録済みカテゴリ")
                            .font(.headline)

                        if categories.isEmpty {
                            Text("まだカテゴリがありません")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(categories) { category in
                                HStack {
                                    categoryBadge(for: category)
                                    Spacer()
                                    if selectedCategoryID == category.id {
                                        Text("選択中")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Button(role: .destructive) {
                                        categoryPendingDeletion = category
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(panelBackground)
                }
            }
            .padding(28)
        }
        .navigationTitle("カテゴリ")
    }

    private var dashboardPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader(
                    title: "ダッシュボード",
                    subtitle: "最近の学習量をざっと見返せるようにしています。"
                )

                HStack(spacing: 16) {
                    summaryCard(title: "今日", value: DashboardStats.durationText(dashboardStats.todayTotal))
                    summaryCard(title: "今週", value: DashboardStats.durationText(dashboardStats.weekTotal))
                    summaryCard(title: "連続", value: "\(dashboardStats.streakDays)日")
                }

                HStack(alignment: .top, spacing: 20) {
                    chartPanel(title: "直近7日", subtitle: "1日のバーをカテゴリ別に積み上げ表示") {
                        VStack(alignment: .leading, spacing: 14) {
                            if dashboardStats.dailyTrend.isEmpty {
                            emptyChartLabel
                            } else {
                                Chart(dashboardStats.dailyTrend) { item in
                                    BarMark(
                                        x: .value("日付", item.label),
                                        y: .value("時間", item.totalDuration / 60)
                                    )
                                    .foregroundStyle(item.color)
                                    .cornerRadius(6)
                                    .opacity(item.isPlaceholder ? 0 : 1)
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading)
                                }
                                .chartXAxis {
                                    AxisMarks(values: dailyTrendLabels) { _ in
                                        AxisValueLabel()
                                    }
                                }
                            }

                            if !trendLegendItems.isEmpty {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                                    ForEach(Array(trendLegendItems.enumerated()), id: \.offset) { _, item in
                                        categoryBadge(name: item.name, color: item.color)
                                    }
                                }
                            }
                        }
                    }

                    chartPanel(title: "カテゴリ別", subtitle: "累計の学習時間") {
                        if dashboardStats.categoryBreakdown.isEmpty {
                            emptyChartLabel
                        } else {
                            Chart(dashboardStats.categoryBreakdown) { item in
                                BarMark(
                                    x: .value("時間", item.totalDuration / 60),
                                    y: .value("カテゴリ", item.categoryName)
                                )
                                .foregroundStyle(item.color.gradient)
                                .cornerRadius(6)
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4))
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("カテゴリ別の合計")
                            .font(.headline)

                        if dashboardStats.categoryBreakdown.isEmpty {
                            Text("まだ学習データがありません")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(dashboardStats.categoryBreakdown) { item in
                                HStack {
                                    categoryBadge(name: item.categoryName, color: item.color)
                                    Spacer()
                                    Text(DashboardStats.durationText(item.totalDuration))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 280, alignment: .leading)
                    .padding(24)
                    .background(panelBackground)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("最近のセッション")
                            .font(.headline)

                        if sessions.isEmpty {
                            Text("まだセッションがありません")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(sessions.prefix(8))) { session in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        categoryBadge(for: session.category)
                                        Text(session.startAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if let endAt = session.endAt {
                                            Text("終了: \(endAt.formatted(date: .omitted, time: .shortened))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("進行中")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 8) {
                                        Text(DashboardStats.durationText(session.duration(at: now)))
                                            .monospacedDigit()

                                        Button(role: .destructive) {
                                            sessionPendingDeletion = session
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(panelBackground)
                }
            }
            .padding(28)
        }
        .navigationTitle("ダッシュボード")
    }

    private func pageHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private func chartPanel<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content()
                .frame(height: 220)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    private var emptyChartLabel: some View {
        ContentUnavailableView(
            "まだ学習データがありません",
            systemImage: "chart.bar",
            description: Text("セッションを記録するとここにグラフが表示されます。")
        )
    }

    private func categoryBadge(for category: StudyCategory) -> some View {
        categoryBadge(name: category.name, color: category.labelColor)
    }

    private func categoryBadge(name: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(name)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.16))
        )
    }

    private var actionHintText: String {
        if categories.isEmpty {
            return "カテゴリページでカテゴリを追加してください。"
        }
        if currentSession == nil {
            return "大きいボタンを押すと学習を開始します。"
        }
        return "もう一度押すと今回の学習セッションを終了します。"
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.11, blue: 0.16),
                Color(red: 0.14, green: 0.11, blue: 0.12),
                Color(red: 0.09, green: 0.10, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var actionButtonGradient: LinearGradient {
        if currentSession == nil {
            return LinearGradient(
                colors: [Color(red: 0.14, green: 0.55, blue: 0.96), Color(red: 0.10, green: 0.34, blue: 0.89)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color(red: 0.92, green: 0.38, blue: 0.39), Color(red: 0.72, green: 0.18, blue: 0.24)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func syncSelectedCategory() {
        if let currentSession {
            selectedCategoryID = currentSession.category.id
            return
        }

        if let selectedCategoryID, categories.contains(where: { $0.id == selectedCategoryID }) {
            return
        }

        selectedCategoryID = categories.first?.id
    }

    private var isDeleteCategoryAlertPresented: Binding<Bool> {
        Binding(
            get: { self.categoryPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    self.categoryPendingDeletion = nil
                }
            }
        )
    }

    private var isDeleteSessionAlertPresented: Binding<Bool> {
        Binding(
            get: { self.sessionPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    self.sessionPendingDeletion = nil
                }
            }
        )
    }

    private func addCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let category = StudyCategory(name: trimmedName, colorHex: selectedColorHex)
        modelContext.insert(category)

        newCategoryName = ""
        selectedCategoryID = category.id

        try? modelContext.save()
        persistWidgetSnapshot()
    }

    private func confirmDeleteCategory() {
        guard let pendingCategory = categoryPendingDeletion else { return }

        let sessionsToDelete = sessions.filter { $0.category.id == pendingCategory.id }
        for session in sessionsToDelete {
            modelContext.delete(session)
        }
        modelContext.delete(pendingCategory)

        if selectedCategoryID == pendingCategory.id {
            selectedCategoryID = categories.first(where: { $0.id != pendingCategory.id })?.id
        }

        categoryPendingDeletion = nil
        try? modelContext.save()
        syncSelectedCategory()
        persistWidgetSnapshot()
    }

    private func confirmDeleteSession() {
        guard let pendingSession = sessionPendingDeletion else { return }

        let deletedSessionID = pendingSession.id
        modelContext.delete(pendingSession)
        sessionPendingDeletion = nil

        if currentSession?.id == deletedSessionID {
            syncSelectedCategory()
        }

        try? modelContext.save()
        persistWidgetSnapshot()
    }

    private func toggleStudy() {
        if currentSession == nil {
            startStudy()
        } else {
            stopStudy()
        }
    }

    private func startStudy() {
        guard currentSession == nil, let selectedCategory else { return }

        let session = StudySession(category: selectedCategory, startAt: now)
        modelContext.insert(session)
        try? modelContext.save()
        persistWidgetSnapshot()
    }

    private func stopStudy() {
        guard let currentSession else { return }

        currentSession.endAt = now
        try? modelContext.save()
        persistWidgetSnapshot()
    }

    private func persistWidgetSnapshot() {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.widgetSuiteName) != nil,
              let widgetDefaults = UserDefaults(suiteName: Self.widgetSuiteName) else {
            return
        }

        let snapshot = DashboardStats.makeWidgetSnapshot(from: sessions, now: now)
        guard let encoded = try? JSONEncoder().encode(snapshot) else { return }

        widgetDefaults.set(encoded, forKey: Self.widgetSnapshotKey)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: Self.widgetKind)
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [StudyCategory.self, StudySession.self], inMemory: true)
}
