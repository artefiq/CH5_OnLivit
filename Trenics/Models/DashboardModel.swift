//
//  DashboardModel.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 12/08/26.
//

import SwiftUI

// MARK: - MODELS
struct MetricModel: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let isPositive: Bool
    let description: String
    let accentColor: Color
    let valueColor: Color
}

struct AppItemModel: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let iconName: String
}
