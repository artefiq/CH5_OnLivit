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
    /// The App Store Connect app id for real apps, so rows keep a stable
    /// identity across refreshes. Falls back to a generated id for samples
    /// and previews.
    let id: String
    let name: String
    let description: String
    let iconName: String

    init(id: String = UUID().uuidString, name: String, description: String, iconName: String) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
    }

    /// Maps an app fetched from App Store Connect onto the dashboard's row model.
    /// The API exposes no description field, so the bundle id (or SKU) stands in
    /// as the secondary line.
    init(app: AppResource) {
        self.id = app.id
        self.name = app.attributes.name
        self.description = app.attributes.bundleId ?? app.attributes.sku ?? ""
        self.iconName = "circle.hexagongrid.fill"
    }
}
