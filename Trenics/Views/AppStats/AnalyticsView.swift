import SwiftUI
import Charts

struct AnalyticsView: View {
    let app: AppResource
    let account: APIAccount

    @State private var selectedCategory: AnalyticsCategory = .impressions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                CategoryPicker(selected: $selectedCategory)

                Group {
                    if selectedCategory == .reviews {
                        ReviewsSection(app: app, account: account)
                    } else {
                        AnalyticsReportSection(app: app, account: account, category: selectedCategory)
                    }
                }
                .id(selectedCategory) // fresh state when switching tabs
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(app.attributes.name)
                .font(.largeTitle.bold())
            Text("App Analytics")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Category picker (chips)

private struct CategoryPicker: View {
    @Binding var selected: AnalyticsCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AnalyticsCategory.allCases) { category in
                    let isSelected = category == selected
                    Button {
                        selected = category
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? category.accentColor : Color(.secondarySystemBackground))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Analytics report section (impressions / downloads / retention / deletions)

private struct AnalyticsReportSection: View {
    let app: AppResource
    let account: APIAccount
    let category: AnalyticsCategory

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    @State private var matchingReports: [AnalyticsReportResource] = []
    @State private var selectedReport: AnalyticsReportResource?
    @State private var table: ReportTable?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title).font(.headline)
                        Text("From Apple's Analytics Reports API").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await loadReports() }
                    } label: {
                        if isLoading && table == nil {
                            ProgressView()
                        } else {
                            Text(matchingReports.isEmpty ? "Load Reports" : "Refresh")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(category.accentColor)
                    .disabled(isLoading)
                }

                if let statusMessage {
                    Text(statusMessage).font(.footnote).foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if matchingReports.count > 1 {
                    Picker("Report", selection: $selectedReport) {
                        Text("Select a report").tag(Optional<AnalyticsReportResource>.none)
                        ForEach(matchingReports) { report in
                            Text(report.attributes.name).tag(Optional(report))
                        }
                    }
                    .pickerStyle(.menu)
                }

                if !matchingReports.isEmpty {
                    Button {
                        Task { await fetchLatestData() }
                    } label: {
                        if isLoading && table != nil {
                            ProgressView()
                        } else {
                            Text("Fetch Latest Data")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(effectiveReport == nil || isLoading)
                }
            }

            if let table {
                let daily = ReportAggregation.dailyMetrics(from: table, category: category)

                if !daily.isEmpty {
                    SectionCard {
                        HStack(spacing: 16) {
                            StatCard(title: "Total", value: formatted(daily.reduce(0) { $0 + $1.value }), color: category.accentColor)
                            StatCard(title: "Latest Day", value: formatted(daily.last?.value ?? 0), color: category.accentColor)
                            StatCard(title: "Days", value: "\(daily.count)", color: category.accentColor)
                        }

                        Chart(daily) { point in
                            LineMark(x: .value("Date", point.date, unit: .day), y: .value(category.title, point.value))
                                .foregroundStyle(category.accentColor)
                                .interpolationMethod(.catmullRom)
                            AreaMark(x: .value("Date", point.date, unit: .day), y: .value(category.title, point.value))
                                .foregroundStyle(category.accentColor.opacity(0.15))
                                .interpolationMethod(.catmullRom)
                        }
                        .frame(height: 220)
                        .padding(.top, 4)
                    }
                } else {
                    SectionCard {
                        Text("Loaded \(table.rows.count) rows, but couldn't find a date + \(category.title.lowercased()) column pair to chart. Raw data is below.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                SectionCard {
                    Text("Raw Data (\(table.rows.count) rows)").font(.headline)
                    DataTable(table: table)
                }
            }
        }
    }

    private var effectiveReport: AnalyticsReportResource? {
        selectedReport ?? matchingReports.first
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func loadReports() async {
        isLoading = true
        errorMessage = nil
        table = nil
        defer { isLoading = false }
        do {
            let client = AppStoreConnectClient(issuerId: account.issuerId, keyId: account.keyId, privateKeyPEM: account.privateKeyPEM)
            let requestId = try await client.findOrCreateOngoingRequest(appId: app.id)
            statusMessage = "Using analytics request \(requestId). A newly created ONGOING request can take up to 48 hours before Apple starts populating data."

            let allReports = try await client.fetchReports(requestId: requestId)
            let keywords = category.reportNameKeywords
            matchingReports = allReports.filter { report in
                let name = report.attributes.name.lowercased()
                return keywords.contains { name.contains($0) }
            }
            if matchingReports.isEmpty {
                errorMessage = "No \(category.title.lowercased()) report found among \(allReports.count) available reports for this app yet."
            }
            selectedReport = matchingReports.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchLatestData() async {
        guard let report = effectiveReport else { return }
        isLoading = true
        errorMessage = nil
        table = nil
        defer { isLoading = false }
        do {
            let client = AppStoreConnectClient(issuerId: account.issuerId, keyId: account.keyId, privateKeyPEM: account.privateKeyPEM)
            let instances = try await client.fetchInstances(reportId: report.id)
            let sortedInstances = instances.sorted { $0.attributes.processingDate > $1.attributes.processingDate }
            guard let latest = sortedInstances.first else {
                errorMessage = "No report instances are available yet for this report."
                return
            }
            let segments = try await client.fetchSegments(instanceId: latest.id)
            var combined: ReportTable?
            for segment in segments {
                let raw = try await client.downloadSegment(url: segment.attributes.url)
                let decompressed = try Gzip.decompress(raw)
                let parsed = ReportParser.parseTSV(decompressed)
                if let existing = combined {
                    combined = ReportTable(headers: existing.headers, rows: existing.rows + parsed.rows)
                } else {
                    combined = parsed
                }
            }
            table = combined
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Reviews & ratings section

private struct ReviewsSection: View {
    let app: AppResource
    let account: APIAccount

    @State private var reviews: [CustomerReviewResource] = []
    @State private var responses: [String: CustomerReviewResponseResource] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reviews & Ratings").font(.headline)
                        Text("From the Customer Reviews API").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await loadReviews() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(reviews.isEmpty ? "Load Reviews" : "Refresh")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isLoading)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if !reviews.isEmpty {
                let summary = ReviewsSummary(reviews: reviews)

                SectionCard {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(format: "%.1f", summary.averageRating))
                                .font(.system(size: 40, weight: .bold))
                            StarRatingView(rating: summary.averageRating)
                            Text("\(reviews.count) reviews loaded")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Chart {
                            ForEach((1...5).reversed(), id: \.self) { star in
                                BarMark(
                                    x: .value("Count", summary.countsByStar[star] ?? 0),
                                    y: .value("Stars", "\(star)★")
                                )
                                .foregroundStyle(.orange)
                            }
                        }
                        .frame(height: 120)
                    }
                }

                SectionCard {
                    Text("Recent Reviews").font(.headline)
                    VStack(spacing: 12) {
                        ForEach(reviews) { review in
                            ReviewCard(
                                review: review,
                                response: responses[review.id],
                                onLoadResponse: { await loadResponse(for: review) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func loadReviews() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = AnalyticsAPIClient(account: account)
            reviews = try await client.fetchAppReviews(appId: app.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadResponse(for review: CustomerReviewResource) async {
        guard responses[review.id] == nil else { return }
        do {
            let client = AnalyticsAPIClient(account: account)
            if let response = try await client.fetchReviewResponse(reviewId: review.id) {
                responses[review.id] = response
            }
        } catch {
            // Non-fatal: just leave this review without a response shown.
        }
    }
}

// MARK: - Reusable pieces

private struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StarRatingView: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: symbolName(for: star))
                    .foregroundStyle(.orange)
                    .font(.subheadline)
            }
        }
    }

    private func symbolName(for star: Int) -> String {
        let diff = rating - Double(star - 1)
        if diff >= 1 { return "star.fill" }
        if diff >= 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

private struct ReviewCard: View {
    let review: CustomerReviewResource
    let response: CustomerReviewResponseResource?
    let onLoadResponse: () async -> Void

    @State private var isCheckingResponse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StarRatingView(rating: Double(review.attributes.rating))
                Spacer()
                Text(review.attributes.createdDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let title = review.attributes.title, !title.isEmpty {
                Text(title).font(.subheadline.bold())
            }

            Text(review.attributes.body)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if let nickname = review.attributes.reviewerNickname {
                    Text(nickname).font(.caption).foregroundStyle(.secondary)
                }
                if let territory = review.attributes.territory {
                    Text("· \(territory)").font(.caption).foregroundStyle(.secondary)
                }
            }

            if let response {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Developer Response").font(.caption.bold())
                    Text(response.attributes.responseBody).font(.caption)
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Button("Check for Developer Response") {
                    isCheckingResponse = true
                    Task {
                        await onLoadResponse()
                        isCheckingResponse = false
                    }
                }
                .font(.caption)
                .disabled(isCheckingResponse)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct DataTable: View {
    let table: ReportTable

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(table.headers, id: \.self) { header in
                        Text(header)
                            .font(.caption.bold())
                            .frame(minWidth: 110, alignment: .leading)
                            .padding(.vertical, 6)
                    }
                }
                Divider()
                ForEach(Array(table.rows.prefix(200).enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.caption)
                                .frame(minWidth: 110, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    }
                    .background(rowIndex.isMultiple(of: 2) ? Color.clear : Color(.systemGray6))
                }
            }
        }
        .frame(maxHeight: 320)
    }
}
