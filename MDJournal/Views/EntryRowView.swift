import SwiftUI

internal enum EntryRowLayoutAxis: Equatable {
    case horizontal
    case vertical
}

internal struct EntryRowLayoutContract: Equatable {
    let metadataAxis: EntryRowLayoutAxis
    let footerAxis: EntryRowLayoutAxis
    let titleLineLimit: Int?

    init(dynamicTypeSize: DynamicTypeSize) {
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize

        metadataAxis = isAccessibilitySize ? .vertical : .horizontal
        footerAxis = isAccessibilitySize ? .vertical : .horizontal
        titleLineLimit = isAccessibilitySize ? nil : 2
    }
}

struct EntryRowView: View {
    let entry: JournalEntry
    let bodyPresentation: JournalEntryBodyPresentation
    var isSelected = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    var body: some View {
        let layout = EntryRowLayoutContract(dynamicTypeSize: dynamicTypeSize)
        let summary = bodyPresentation

        VStack(alignment: .leading, spacing: 6) {
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

            footer(summary, layout: layout)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? JournalTheme.inset : .clear,
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(JournalTheme.accent)
                    .frame(width: 3)
                    .padding(.vertical, 14)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func metadata(layout: EntryRowLayoutContract) -> some View {
        let axis = layout.metadataAxis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 6))

        return axis {
            Text(entry.createdAt.journalTimelineText(calendar: calendar, locale: locale))
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

    private func footer(_ summary: JournalEntryBodyPresentation, layout: EntryRowLayoutContract) -> some View {
        let axis = layout.footerAxis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))

        return axis {
            Label(entry.category.rawValue, systemImage: entry.category.systemImage)
                .foregroundStyle(entry.category.tint)
            if layout.footerAxis == .horizontal { Spacer(minLength: 4) }
            Text("\(summary.wordCount) 词")
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
