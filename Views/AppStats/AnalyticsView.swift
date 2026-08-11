import SwiftUI
import Charts

struct AnalyticsView: View {
    let app: AppResource
    @ObservedObject var credentials: CredentialsStore
    @State private var reports: [AnalyticsReportResource] = []
    @State private var selectedReport: AnalyticsReportResource?
    @State private var table: ReportTable?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("App Analytics — \(app.attributes.name)").font(.title2.bold())
                Spacer()
                Button(isLoading ? "Loading..." : "Load Available Reports") { Task { await loadReports() } }
                    .disabled(isLoading || !credentials.isComplete)
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
            if let statusMessage {
                Text(statusMessage).font(.footnote).foregroundStyle(.secondary)
            }

            if !reports.isEmpty {
                Picker("Report", selection: $selectedReport) {
                    Text("Select a report").tag(Optional<AnalyticsReportResource>.none)
                    ForEach(reports) { report in
                        Text("\(report.attributes.name) (\(report.attributes.category))")
                            .tag(Optional(report))
                    }
                }
                Button("Fetch Latest Data") { Task { await fetchLatestData() } }
                    .disabled(selectedReport == nil || isLoading)
            }

            if let table {
                if let idx = bestNumericColumnIndex(table) {
                    Chart(Array(table.rows.prefix(30).enumerated()), id: \.offset) { pair in
                        BarMark(
                            x: .value("Row", pair.offset),
                            y: .value(table.headers[idx], Double(pair.element[safe: idx] ?? "") ?? 0)
                        )
                    }
                    .frame(height: 200)
                }
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            ForEach(table.headers, id: \.self) { header in
                                Text(header).bold().frame(minWidth: 100, alignment: .leading)
                            }
                        }
                        Divider()
                        ForEach(Array(table.rows.prefix(200).enumerated()), id: \.offset) { _, row in
                            HStack {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                    Text(cell).frame(minWidth: 100, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
    }

    private func bestNumericColumnIndex(_ table: ReportTable) -> Int? {
        for (i, header) in table.headers.enumerated() {
            let lower = header.lowercased()
            if lower.contains("count") || lower.contains("units") || lower.contains("installations") {
                return i
            }
        }
        return nil
    }

    private func loadReports() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let client = credentials.makeClient()
            let requestId = try await client.findOrCreateOngoingRequest(appId: app.id)
            statusMessage = "Using analytics request \(requestId). Note: a newly created ONGOING request can take up to 48 hours before Apple starts populating data."
            reports = try await client.fetchReports(requestId: requestId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchLatestData() async {
        guard let selectedReport else { return }
        isLoading = true
        errorMessage = nil
        table = nil
        defer { isLoading = false }
        do {
            let client = credentials.makeClient()
            let instances = try await client.fetchInstances(reportId: selectedReport.id)
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
