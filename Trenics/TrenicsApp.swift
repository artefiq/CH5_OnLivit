//
//  TrenicsApp.swift
//  Trenics
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 11/08/26.
//

import SwiftUI

@main
struct TrenicsApp: App {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var accountsStore = AccountsStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    DashboardView(accountsStore: accountsStore)
                } else {
                    OnboardingView(accountsStore: accountsStore) {
                        hasSeenOnboarding = true
                    }
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
