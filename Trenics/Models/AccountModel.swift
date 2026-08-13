//
//  AccountModel.swift
//  Trenics
//
//  Created by Ahmad Taufiq Hidayat on 13/08/26.
//

import SwiftUI

struct AccountModel: Identifiable, Equatable {
    let id = UUID()
    let initials: String
    let name: String
    let appCount: Int
    let syncStatus: String
    let avatarColor: Color
}
