//
//  MainLayout.swift
//  Trenics
//
//  Created by Ida Bagus Putu Ryan Paramasatya Putra on 11/08/26.
//
import SwiftUI

struct MainLayout<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color("baseBGColor")
                .ignoresSafeArea()

            VStack {
                Image(.backgroundTexture)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .top)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
