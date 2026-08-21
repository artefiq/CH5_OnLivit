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
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
