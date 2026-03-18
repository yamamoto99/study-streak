//
//  StudyStreakApp.swift
//  StudyStreak
//
//  Created by Masato Yamamoto on 2026/03/13.
//

import SwiftData
import SwiftUI

@main
struct StudyStreakApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [StudyCategory.self, StudySession.self])
    }
}
