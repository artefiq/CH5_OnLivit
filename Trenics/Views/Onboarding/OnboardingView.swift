//
//  OnboardingView.swift
//  Trenics
//

import SwiftUI

/// Shown once, on first launch, before the app has any account to work with.
///
/// The last page leads into the credentials form rather than the dashboard,
/// because a dashboard with no connected account has nothing to show.
struct OnboardingView: View {
    @ObservedObject var accountsStore: AccountsStore
    /// Called when the user is done here, whether they added an account or
    /// backed out of the form.
    let onFinished: () -> Void

    @State private var page = 0
    @State private var isShowingCredentials = false
    /// Set once the form has been opened, so backing out of it finishes
    /// onboarding instead of stranding the user on the last page.
    @State private var hasOpenedCredentials = false

    private let pages = OnboardingPage.all

    var body: some View {
        NavigationStack {
            MainLayout {
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { index, item in
                            OnboardingPageView(page: item, isCurrent: page == index)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    PrimaryButton(title: pages[page].buttonTitle) {
                        advance()
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                    PageDots(count: pages.count, current: page)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                }
            }
            .navigationDestination(isPresented: $isShowingCredentials) {
                CredentialsView(accountsStore: accountsStore)
            }
        }
        // Covers both ways out of the form: saving dismisses it, and so does
        // the back button.
        .onChange(of: isShowingCredentials) { _, isShowing in
            if !isShowing && hasOpenedCredentials {
                onFinished()
            }
        }
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) { page += 1 }
        } else {
            hasOpenedCredentials = true
            isShowingCredentials = true
        }
    }
}

// MARK: - Page content

struct OnboardingPage: Identifiable, Equatable {
    let id: Int
    let imageName: String
    let title: String
    /// Rendered in the accent colour, on its own line.
    let highlight: String
    let subtitle: String
    let buttonTitle: String
    /// True when the highlight follows the title, false when it leads.
    let highlightTrails: Bool

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            imageName: "Onboarding1",
            title: "All your app numbers",
            highlight: "in one place.",
            subtitle: "Impressions, retention, and reviews — updated for every app you own.",
            buttonTitle: "NEXT",
            highlightTrails: true
        ),
        OnboardingPage(
            id: 1,
            imageName: "Onboarding2",
            title: "Explained in",
            highlight: "plain English.",
            subtitle: "Every chart comes with a short answer to “what does it mean?”",
            buttonTitle: "NEXT",
            highlightTrails: true
        ),
        OnboardingPage(
            id: 2,
            imageName: "Onboarding3",
            title: "You’re",
            highlight: "all set!",
            subtitle: "Let’s turn your data into growth.",
            buttonTitle: "CONTINUE",
            highlightTrails: false
        )
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    /// Drives the entrance animation, so it replays each time the page is
    /// scrolled back to rather than only on first build.
    let isCurrent: Bool

    @State private var hasAppeared = false
    @State private var isFloating = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260, maxHeight: 300)
                .scaleEffect(hasAppeared ? 1 : 0.72)
                .opacity(hasAppeared ? 1 : 0)
                .rotationEffect(.degrees(hasAppeared ? 0 : -8))
                // A slow drift once it has landed, so the illustration doesn't
                // sit completely dead on the screen.
                .offset(y: isFloating ? -8 : 8)
                .animation(
                    .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                    value: isFloating
                )

            Spacer(minLength: 24)

            VStack(spacing: 10) {
                Text(headline)
                    .font(.title.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 16)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if isCurrent { play() } }
        .onChange(of: isCurrent) { _, current in
            if current { play() } else { reset() }
        }
    }

    /// Built as an AttributedString so the accent phrase can carry its own
    /// colour inside one centred, wrapping headline.
    private var headline: AttributedString {
        var lead = AttributedString(page.title)
        lead.foregroundColor = .primary

        var separator = AttributedString(page.highlightTrails ? "\n" : " ")
        separator.foregroundColor = .primary

        var accent = AttributedString(page.highlight)
        accent.foregroundColor = Color("primaryPurple")

        return lead + separator + accent
    }

    private func play() {
        withAnimation(.spring(response: 0.65, dampingFraction: 0.62)) {
            hasAppeared = true
        }
        isFloating = true
    }

    private func reset() {
        isFloating = false
        hasAppeared = false
    }
}

// MARK: - Dots

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? Color("primaryPurple") : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}
