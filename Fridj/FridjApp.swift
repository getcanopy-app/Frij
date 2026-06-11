//
//  FridjApp.swift
//  Fridj
//
//  Created by ardy on 2026-05-27.
//

import SwiftUI

@main
struct FridjApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .task {
                    NotificationScheduler.shared.requestPermission()
                    NotificationScheduler.shared.scheduleStreakReminder()
                }
        }
    }
}
