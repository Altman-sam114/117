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

/// Only displayed values participate in row invalidation; the body and section array stay in the store.
struct JournalEntryRowContent: Equatable, Sendable {
    let id: JournalEntry.ID
    let title: String
    let createdAt: Date
    let category: JournalEntry.Category
    let mood: JournalEntry.Mood
    let excerpt: String
    let wordCount: Int

    init(entry: JournalEntry, bodyPresentation: JournalEntryBodyPresentation) {
        id = entry.id
        title = entry.displayTitle
        createdAt = entry.createdAt
        category = entry.category
        mood = entry.mood
        excerpt = bodyPresentation.excerpt
        wordCount = bodyPresentation.wordCount
    }
}

struct EntryRowView: View, Equatable {
    let content: JournalEntryRowContent
    let isSelected: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .title2) private var dateStampWidth: CGFloat = 34

    init(entry: JournalEntry, bodyPresentation: JournalEntryBodyPresentation, isSelected: Bool = false) {
        content = JournalEntryRowContent(entry: entry, bodyPresentation: bodyPresentation)
        self.isSelected = isSelected
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.content == rhs.content && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        let layout = EntryRowLayoutContract(dynamicTypeSize: dynamicTypeSize)
        let rowLayout = layout.metadataAxis == .vertical
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))

        rowLayout {
            dateStamp(layout: layout)
            VStack(alignment: .leading, spacing: 8) {
                Text(content.title)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(layout.titleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)

                Text(content.excerpt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                footer(layout: layout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
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

    @ViewBuilder
    private func dateStamp(layout: EntryRowLayoutContract) -> some View {
        if layout.metadataAxis == .vertical {
            Text(content.createdAt.journalTimelineText(calendar: calendar, locale: locale))
                .font(.caption)
                .foregroundStyle(isSelected ? JournalTheme.accent : .secondary)
        } else {
            VStack(spacing: 2) {
                Text(content.createdAt.journalDayText(calendar: calendar, locale: locale))
                    .font(.system(.title2, design: .serif).weight(.medium))
                    .foregroundStyle(isSelected ? JournalTheme.accent : .primary)
                Text(content.createdAt.journalWeekdayText(calendar: calendar, locale: locale))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(JournalTheme.accent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .frame(width: dateStampWidth)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(content.createdAt.journalTimelineText(calendar: calendar, locale: locale))
        }
    }

    private func footer(layout: EntryRowLayoutContract) -> some View {
        let axis = layout.footerAxis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 8))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 4))

        return axis {
            HStack(spacing: 8) {
                Label(content.category.rawValue, systemImage: content.category.systemImage)
                    .foregroundStyle(JournalTheme.accent)
                Label(content.mood.rawValue, systemImage: content.mood.systemImage)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
            }
            if layout.footerAxis == .horizontal { Spacer(minLength: 4) }
            Text("\(content.wordCount) 词")
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
