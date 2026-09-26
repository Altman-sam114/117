import SwiftUI

internal enum EntryRowLayoutAxis: Equatable {
    case horizontal
    case vertical
}

internal struct EntryRowLayoutContract: Equatable {
    let metadataAxis: EntryRowLayoutAxis
    let footerAxis: EntryRowLayoutAxis
    let titleLineLimit: Int?
    let sectionTitleLineLimit: Int
    let usesVerticalSectionLayout: Bool

    init(dynamicTypeSize: DynamicTypeSize) {
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize

        metadataAxis = isAccessibilitySize ? .vertical : .horizontal
        footerAxis = isAccessibilitySize ? .vertical : .horizontal
        titleLineLimit = isAccessibilitySize ? nil : 1
        sectionTitleLineLimit = isAccessibilitySize ? 2 : 1
        usesVerticalSectionLayout = isAccessibilitySize
    }
}

struct EntryRowView: View {
    let entry: JournalEntry
    var isSelected = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = EntryRowLayoutContract(dynamicTypeSize: dynamicTypeSize)
        let summary = entry.bodySummary

        VStack(alignment: .leading, spacing: 10) {
            metadata(layout: layout)

            Text(entry.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(layout.titleLineLimit)

            Text(summary.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !summary.sections.isEmpty {
                if layout.usesVerticalSectionLayout {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(summary.sections.prefix(3)) { section in
                            Text(section.title).lineLimit(layout.sectionTitleLineLimit)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text(summary.sections.prefix(3).map(\.title).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(layout.sectionTitleLineLimit)
                }
            }

            footer(summary, layout: layout)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? JournalTheme.inset : JournalTheme.paper,
                    in: RoundedRectangle(cornerRadius: JournalTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: JournalTheme.cornerRadius)
                .strokeBorder(isSelected ? JournalTheme.accent : JournalTheme.separator,
                              lineWidth: isSelected ? 1.5 : 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: JournalTheme.cornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func metadata(layout: EntryRowLayoutContract) -> some View {
        let axis = layout.metadataAxis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 6))

        return axis {
            Text(entry.createdAt.journalListText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            if layout.metadataAxis == .horizontal { Spacer(minLength: 4) }
            HStack(spacing: 8) {
                Label(entry.mood.rawValue, systemImage: entry.mood.systemImage)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(JournalTheme.accent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .font(.caption)
        }
    }

    private func footer(_ summary: JournalEntryBodySummary, layout: EntryRowLayoutContract) -> some View {
        let axis = layout.footerAxis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))

        return axis {
            Label(entry.category.rawValue, systemImage: entry.category.systemImage)
                .foregroundStyle(entry.category.tint)
            if layout.footerAxis == .horizontal { Spacer(minLength: 4) }
            Text("\(summary.wordCount) 词 · \(summary.sectionCount) 小节")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension JournalEntry.Category {
    var tint: Color {
        switch self {
        case .daily:
            return .teal
        case .workStudy:
            return .indigo
        case .inspiration:
            return .orange
        case .travel:
            return .blue
        case .health:
            return .pink
        }
    }
}
