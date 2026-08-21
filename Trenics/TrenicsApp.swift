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
    @StateObject private var accountsStore = AccountsStore()
    
    var body: some Scene {
        WindowGroup {
            DashboardView(accountsStore: accountsStore)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
