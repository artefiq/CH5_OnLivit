import SwiftUI

struct InsightDisclosure<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    var startsExpanded: Bool = false
    @ViewBuilder var content: Content

    @State private var isExpanded: Bool?

    private var expanded: Bool { isExpanded ?? startsExpanded }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded = !expanded }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.subheadline)
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    content
                    OnDeviceBadge()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.07)))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
    }
}

/// "Summary" — what the numbers show, as numbered findings.
struct AISummaryDisclosure: View {
    let findings: [InsightFinding]
    var isLoading: Bool = false
    var unavailableMessage: String?

    var body: some View {
        InsightDisclosure(
            title: "Summary",
            systemImage: "wand.and.sparkles.inverse",
            tint: Color("primaryPurple")
        ) {
            if isLoading {
                InsightProgressLine(text: "Reading your numbers…")
            } else if findings.isEmpty {
                Text(unavailableMessage ?? "Not enough data to summarise this period yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(findings.enumerated()), id: \.element.id) { index, finding in
                    if index > 0 { Divider() }
                    NumberedItem(index: index + 1, title: finding.title) {
                        ForEach(finding.points, id: \.self) { point in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("•").foregroundStyle(.secondary)
                                Text(point)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !finding.plainMeaning.isEmpty {
                            // The point of this line is that it carries no
                            // jargon, so it is set apart from the observations.
                            Text(Self.simpleTerms(finding.plainMeaning))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                    }
                }
            }
        }
    }
}

/// "Next Step" — what to do about it, as numbered actions.
extension AISummaryDisclosure {
    /// Built as an AttributedString so the label and the sentence can carry
    /// different styling within one wrapping paragraph.
    fileprivate static func simpleTerms(_ meaning: String) -> AttributedString {
        var label = AttributedString("In simple terms: ")
        label.font = .subheadline.bold()
        var body = AttributedString(meaning)
        body.font = .subheadline.italic()
        return label + body
    }
}

struct AINextStepDisclosure: View {
    let actions: [InsightAction]
    var isLoading: Bool = false

    var body: some View {
        InsightDisclosure(
            title: "Next Step",
            systemImage: "lightbulb.fill",
            tint: .orange
        ) {
            if isLoading {
                InsightProgressLine(text: "Working out what to do…")
            } else if actions.isEmpty {
                Text("No recommendation for this period.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    if index > 0 { Divider() }
                    NumberedItem(index: index + 1, title: action.title) {
                        // Steps rather than a paragraph: the point of this block
                        // is that it can be worked through, not just read.
                        ForEach(Array(action.steps.enumerated()), id: \.offset) { step, text in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(step + 1).")
                                    .font(.caption.bold().monospacedDigit())
                                    .foregroundStyle(Color("primaryPurple"))
                                Text(text)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// A numbered heading with its supporting lines indented underneath.
private struct NumberedItem<Content: View>: View {
    let index: Int
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(index).")
                .font(.subheadline.bold())
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.bold())
                    .fixedSize(horizontal: false, vertical: true)
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InsightProgressLine: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
