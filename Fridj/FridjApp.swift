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
                    // Count new installs once, ever — the "new users" signal.
                    if !UserDefaults.standard.bool(forKey: "frij.firstOpenReported") {
                        UserDefaults.standard.set(true, forKey: "frij.firstOpenReported")
                        FrijAPI.reportEvent("first_open")
                    }
                    #if DEBUG
                    // Ad/demo only — puts the filmable meals on Home. Compiled
                    // out of App Store (Release) builds entirely.
                    DebugHomeSeed.apply()
                    #endif
                }
        }
    }
}
